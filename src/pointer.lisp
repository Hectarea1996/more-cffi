
(in-package #:mcffi)
(in-readtable mcffi)


(cffi:define-foreign-type pointer-type ()
  ((ctype :initarg :ctype)))

(cffi:define-parse-method pointer (ctype)
  (make-instance 'pointer-type :ctype ctype :actual-type :pointer))

(defclass pointer ()
  ((cpointer :initarg :cpointer)
   (ctype :initarg :ctype)
   (subpointers :initarg :subpointers
                :initform nil)
   (owner :initarg :owner
          :initform nil)))

(defmethod cffi:translate-to-foreign ((object pointer) (obj-type pointer-type))
  (declare (ignore obj-type))
  (with ((cpointer (slots object)))
    (values cpointer)))

(defmethod cffi:translate-from-foreign (pointer (obj-type pointer-type))
  (with ((ctype (slots obj-type)))
    (make-instance 'pointer :cpointer pointer :ctype ctype)))

(defmethod cffi:free-translated-object (pointer (obj-type pointer-type) param)
  (declare (ignore param))
  (values))

;; TODO: Implement expand methods


(defmethod own ((owner pointer) (obj pointer))
  (with ((subpointers (slots owner)))
    (push obj subpointers)))

(defmethod disown ((owner pointer) (obj pointer))
  (with ((subpointers (slots owner)))
    (setf subpointers (delete obj subpointers :test 'eq))))

(defmethod get-owned ((owner pointer))
  (slot-value owner 'subpointers))

(defmethod get-owner ((obj pointer))
  (slot-value obj 'owner))

(defmethod set-owner ((obj pointer) owner)
  (setf (slot-value obj 'owner) owner))


(defmethod slot-missing (class (obj pointer) slot-name (op (eql 'slot-value)) &optional new-value)
  (with (((cpointer ctype) (slots obj)))
    (if (member slot-name (cffi:foreign-slot-names ctype))
        (cffi:foreign-slot-value cpointer ctype slot-name)
        (call-next-method))))

(defmethod slot-missing (class (obj pointer) slot-name (op (eql 'setf)) &optional new-value)
  (with ((*owner* obj)
         ((cpointer ctype) (slots obj)))
    (if (member slot-name (cffi:foreign-slot-names ctype))
        (setf (cffi:foreign-slot-value cpointer ctype slot-name) new-value)
        (call-next-method))))

(defmethod slot-missing (class (obj pointer) slot-name (op (eql 'slot-boundp)) &optional new-value)
  (member slot-name (cffi:foreign-slot-names ctype)))

(defmethod slot-missing (class (obj pointer) slot-name (op (eql 'slot-makunbound)) &optional new-value)
  (with ((ctype (slots obj)))
    (if (member slot-name (cffi:foreign-slot-names ctype))
        (error "The slot ~s cannot be unbound." slot-name)
        (call-next-method))))


;; ------ public functions ------
(defun foreign-free (ptr)
  (check-type ptr pointer)
  (with (((cpointer subpointers) (slots ptr)))
    (loop for subpointer in subpointers
          do (cffi:foreign-free subpointer))
    (cffi:foreign-free cpointer)))

(defun foreign-alloc (ctype &rest args &key initial-element initial-contents (count 1) null-terminated-p)
  (let* ((cpointer (apply #'cffi:foreign-alloc ctype args))
         (pointer-instance (make-instance 'pointer
                                          :cpointer cpointer
                                          :ctype ctype)))
    (when *owner*
      (establish-ownership *owner* pointer-instance))
    (values pointer-instance)))

(defun foreign-symbol-pointer (foreign-name ctype &rest args &key library)
  (let ((cpointer (apply #'cffi:foreign-symbol-pointer foreign-name args)))
    (and cpointer
         (make-instance 'pointer :cpointer cpointer :ctype ctype))))

(defun inc-pointer (ptr offset)
  (check-type ptr pointer)
  (with ((cpointer (slots ptr)))
    (cffi:inc-pointer cpointer offset)))

(defmacro incf-pointer (place &optional (offset 1))
  (with-gensyms (cpointer-sym)
    `(with-slots ((,cpointer-sym cpointer)) ,place
       (cffi:incf-pointer ,cpointer-sym ,offset))))

(defun make-pointer (address ctype)
  (make-instance 'pointer
                 :cpointer (cffi:make-pointer address)
                 :ctype ctype))

(defun mem-aptr (ptr &optional (index 0))
  (check-type ptr pointer)
  (with (((cpointer ctype) (slots ptr)))
    (cffi:mem-aptr cpointer ctype index)))

(defun mem-aref (ptr &optional (index 0))
  (check-type ptr pointer)
  (with (((cpointer ctype) (slots ptr)))
    (cffi:mem-aref cpointer ctype index)))

(defun (setf mem-aref) (new-value ptr &optional (index 0))
  (check-type ptr pointer)
  (with ((*owner* ptr)
         ((cpointer ctype) (slots ptr)))
    (setf (cffi:mem-aref cpointer ctype index) new-value)))

(defun mem-ref (ptr &optional offset)
  (check-type ptr pointer)
  (with (((cpointer ctype) (slots ptr)))
    (cffi:mem-ref cpointer ctype offset)))

(defun (setf mem-ref) (new-value ptr &optional offset)
  (check-type ptr pointer)
  (with ((*owner* ptr)
         ((cpointer ctype) (slots ptr)))
    (setf (cffi:mem-ref cpointer ctype offset) new-value)))

(defun null-pointer ()
  (make-instance 'pointer
                 :cpointer (cffi:null-pointer)
                 :ctype :void))

(defun null-pointer-p (ptr)
  (check-type ptr pointer)
  (with ((cpointer (slots ptr)))
    (cffi:null-pointer-p cpointer)))

(defun pointerp (ptr)
  (typep ptr 'pointer))

(defun pointer-address (ptr)
  (check-type ptr pointer)
  (with ((cpointer (slots ptr)))
    (cffi:pointer-address ptr)))

(defun pointer-eq (ptr1 ptr2)
  (with ((((cpointer1 cpointer)) (slots ptr1))
         (((cpointer2 cpointer)) (slots ptr2)))
    (cffi:pointer-eq cpointer1 cpointer2)))

(defmacro with-foreign-pointer ((var size &optional size-var) &body body)
  (with-gensyms (cvar)
    `(cffi:with-foreign-pointer (,cvar ,size ,size-var)
       (let ((,var (make-instance 'pointer
                                  :cpointer ,cvar
                                  :ctype :void)))
         ,@body))))


;; struct related

(defun foreign-slot-pointer (ptr slot-name)
  (check-type ptr pointer)
  (with (((cpointer ctype) (slots ptr)))
    (cffi:foreign-slot-pointer cpointer ctype slot-name)))

(defun foreign-slot-value (ptr slot-name)
  (check-type ptr pointer)
  (with (((cpointer ctype) (slots ptr)))
    (cffi:foreign-slot-value cpointer ctype slot-name)))

(defun (setf foreign-slot-value) (new-value ptr slot-name)
  (check-type ptr pointer)
  (with ((*owner* ptr)
         ((cpointer ctype) (slots ptr)))
    (setf (cffi:foreign-slot-value cpointer ctype slot-name) new-value)))

(defmacro with-foreign-object ((var ctype &optional count) &body body)
  (with-gensyms (cvar ev-type)
    `(let ((,ev-type ,ctype))
       (cffi:with-foreign-object (,cvar ,ev-type ,count)
         (let ((,var (make-instance 'pointer
                                    :cpointer ,cvar
                                    :ctype ,ev-type)))
           ,@body)))))


(eval-when (:compile-toplevel :load-toplevel :execute)
  
  (defun make-foreign-slot-binding (var ptr-sym type-sym)
    (cond
      ((symbolp var)
       `(,var (cffi:foreign-slot-value ,ptr-sym ,type-sym ',var)))
      ((listp var)
       (let ((num-elems (length var)))
         (when (not (null var))
           (let ((binding-var (car var)))
             (cond
               ((= num-elems 1)
                `(,binding-var (cffi:foreign-slot-value ,ptr-sym ,type-sym ',binding-var)))
               ((= num-elems 2)
                (let ((option (cadr var)))
                  (if (eq option :pointer)
                      `(,binding-var (cffi:foreign-slot-pointer ,ptr-sym ,type-sym ',binding-var))
                      `(,binding-var (cffi:foreign-slot-value ,ptr-sym ,type-sym ',option)))))
               ((and (= num-elems 3) (member :pointer var))
                (let ((slot (if (eq (cadr var) :pointer) (caddr var) (cadr var))))
                  `(,binding-var (cffi:foreign-slot-pointer ,ptr-sym ,type-sym ',slot))))))))))))

(defmacro with-foreign-slots (vars (ptr) &body body)
  (with-gensyms (ptr-sym type-sym)
    (let ((macrolet-bindings (mapcar #¿(make-foreign-slot-binding ? ptr-sym type-sym) (ensure-list vars))))
      `(with ((((,ptr-sym cpointer) (,type-sym ctype)) (slots ,ptr)))
         (symbol-macrolet ,macrolet-bindings
           ,@body)))))

(defwith foreign-slots (vars (ptr) &body body)
  `(with-foreign-slots ,vars (,ptr)
     ,@body))
