;;; helm-org-clock.el --- Org mode clock management with Helm.
;; Copyright 2017 Tim Nicolson
;;
;; Author: Tim Nicolson <tim@nicolson.info>
;; Keywords: helm org clock
;; URL: https://github.com/tnicolson/helm-org-clock
;; Created: 28th October 2017
;; Version: 0.1.1

;;; Commentary:
;;
;; Set helm-org-clock-targets to a list of org files and levels you which to
;; manage. This takes the same form as org-refile-targets.
;;
;; Calling helm-org-clock will present you with a list of task. Hitting return
;; will start the clock. You're current task is presented first - selecting that
;; will clock out.
;;
;; This is my first elisp package and remains a work in progress.
;; Suggesting/requests welcome.

(require 'dash)
(require 'helm)
(require 'org-clock)

(defgroup helm-org-clock nil
  "Options concerning clocking in and out of Org mode tasks using `helm'."
  :tag "Helm Org Clock"
  :group 'org)

(defcustom helm-org-clock-targets nil
  "Targets for clock in and out of with `\\[helm-org-clock]'."
  :group 'helm-org-clock)

(defun helm-org-clock--format-task (marker)
  ;; TODO this is a cut and paste job - source did not expose this and inserted it
  ;; instead. I guess another option would be to create a temporary buffer, call
  ;; the original method and read the result but that feels ikky.
  (when (marker-buffer marker)
    (let (cat task heading prefix)
      (with-current-buffer (org-base-buffer (marker-buffer marker))
        (org-with-wide-buffer
         (ignore-errors
           (goto-char marker)
           (setq cat (org-get-category)
                 heading (org-get-heading 'notags)
                 prefix (save-excursion
                          (org-back-to-heading t)
                          (looking-at org-outline-regexp)
                          (match-string 0))
                 task (substring
                       (org-fontify-like-in-org-mode
                        (concat prefix heading)
                        org-odd-levels-only)
                       (length prefix))))))
      (if (and cat task)
          (format "%-12s  %s" cat task)))))

(defun helm-org-clock--current-task ()
  (let ((text (helm-org-clock--format-task org-clock-marker)))
    ;; TODO is this the best way?
    (list (list text org-clock-marker))))

(defun helm-org-clock--format-entry (entry)
  ;; TODO there must be a more efficient way of generating markers!?
  (let ((file (nth 1 entry))
        (pos (nth 3 entry))
        (marker (make-marker)))
    (set-marker marker pos (or (find-buffer-visiting file)
                               (find-file-noselect file)))
    (-replace-at 0 (helm-org-clock--format-task marker) entry)
    ))

(defun helm-org-clock--other-tasks ()
  (let ((org-refile-targets helm-org-clock-targets))
    (-map 'helm-org-clock--format-entry (org-refile-get-targets))))

(defun helm-org-clock--clock-in (target)
  "Clock in to the `target' task."
  (unless target
    (error "No target"))
  (let ((file (nth 0 target))
        (pos (nth 2 target)))
    (with-current-buffer (or (find-buffer-visiting file)
                             (find-file-noselect file))
      (org-with-wide-buffer
       (if pos
           (goto-char pos)
         (error "No pos"))
       (org-clock-in)
       ))))

(defun helm-org-clock--clock-out (target)
  (org-clock-out))

(defvar helm-source-org-clock-current-task
  (helm-build-sync-source "Current"
    :candidates #'helm-org-clock--current-task
    :action #'helm-org-clock--clock-out))

(defvar helm-source-org-clock-other-tasks
  (helm-build-sync-source "Others"
    :candidates #'helm-org-clock--other-tasks
    :action #'helm-org-clock--clock-in))

(defun helm-source-org-clock-make-sources ()
  (if (org-clocking-p)
      (list helm-source-org-clock-current-task helm-source-org-clock-other-tasks)
    (list helm-source-org-clock-other-tasks)))

(defun helm-org-clock ()
  "Clock-in/out to/from a task using `helm'."
  (interactive)
  (helm :sources (helm-source-org-clock-make-sources)
        :buffer "*helm-org-clock*"))
