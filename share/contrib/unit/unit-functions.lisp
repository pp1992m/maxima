;; Redefining toplevel-macsyma-eval for post_eval_functions 
;; Define the finaleval list
(defmvar $post_eval_functions `((mlist)))

(defun toplevel-macsyma-eval (x)
;; Functional definition of toplevel-macsyma-eval
  (setq x (meval* x))
  (dolist (fi (margs $post_eval_functions) x)
    (setq x (mfuncall fi x))))


;; Redefine msetchk to protect post_eval_functions from improper assignments
(defmfun msetchk (x y)
  (cond ((memq x '(*read-base* *print-base*))
	 (cond #-nil ((eq y 'roman))
	       ((or (not (fixnump y)) (< y 2) (> y 35)) (mseterr x y))
	       ((eq x '*read-base*)
		#+maclisp (if (< y 11) (sstatus + nil) (sstatus + t)))))
	((memq x '($linel $fortindent $gensumnum $fpprintprec $floatwidth
		   $parsewindow $ttyintnum))
	 (if (not (fixnump y)) (mseterr x y))
	 ;;	#+MacLisp
	 ;;	(WHEN (EQ X '$LINEL)
	 ;;	  (LINEL T (LINEL NIL Y))
	 ;;	  (DOLIST (FILE OUTFILES) (LINEL FILE Y))
	 ;;	  (SETQ LINEL Y))
	 (if (eq x '$linel) (setq linel y))
	 (cond ((and (memq x '($fortindent $gensumnum $floatwidth $ttyintnum)) (< y 0))
		(mseterr x y))
	       ((and (eq x '$parsewindow) (< y -1)) (mseterr x y))
	       ((and (eq x '$fpprintprec) (or (< y 0) (= y 1))) (mseterr x y))))
	((memq x '($genindex $optimprefix)) (if (not (symbolp y)) (mseterr x y)))
	((eq x '$dotassoc) (cput 'mnctimes y 'associative))
	((eq x 'modulus)
	 (cond ((null y))
	       ((integerp y)
		(if (or (not (primep y)) (zl-member y '(1 0 -1)))
		    (mtell "Warning: `modulus' being set to ~:M, a non-prime.~%" y)))
	       (t (mseterr x y))))
	((eq x '$setcheck)
	 (if (not (or (memq y '($all t nil)) ($listp y))) (mseterr x y)))
	((eq x '$gcd) (if (not (or (null y) (memq y *gcdl*))) (mseterr x y)))
	((eq x '$ratvars)
	 (if ($listp y) (apply #'$ratvars (cdr y)) (mseterr x y)))
	((eq x '$ratfac)
	 (if (and y $ratwtlvl)
	     (merror "`ratfac' and `ratwtlvl' may not both be used at the same time.")))
	((eq x '$ratweights)
	 (cond ((not ($listp y)) (mseterr x y))
	       ((null (cdr y)) (kill1 '$ratweights))
	       (t (apply #'$ratweight (cdr y)))))
	((eq x '$ratwtlvl)
	 (if (and y (not (fixnump y))) (mseterr x y))
	 (if (and y $ratfac)
	     (merror "`ratfac' and `ratwtlvl' may not both be used at the same time.")))
	((eq x '$post_eval_functions) 
         (if (not (and ($listp y) (every 'symbolp (margs y))))
             (mseterr x y)))
))


;; Redefine kill1 in order to be able to properly reset post_eval_functions
;; with kill(all) and kill(post_eval_functions)
(defmfun kill1 (x)
  (funcall 
   #'(lambda (z)
       (cond ((and allbutl (memq x allbutl)))
	     ((eq (setq x (getopr x)) '$labels)
	      (dolist (u (cdr $labels))
		(cond ((and allbutl (memq u allbutl))
		       (setq z (nconc z (ncons u))))
		      (t (makunbound u) (remprop u 'time)
			 (remprop u 'nodisp))))
	      (setq $labels (cons '(mlist simp) z) $linenum 0 dcount 0))
	     ((memq x '($values $arrays $aliases $rules $props
			$let_rule_packages))
	      (mapc #'kill1 (cdr (symbol-value x))))
	     ((memq x '($functions $macros $gradefs $dependencies))
	      (mapc #'(lambda (y) (kill1 (caar y))) (cdr (symbol-value x))))
	     ((eq x '$myoptions))
	     ((eq x '$tellrats) (setq tellratlist nil))
	     ((eq x '$ratweights) (setq *ratweights
					nil $ratweights '((mlist simp))))
	     ((eq x '$features)
	      (cond ((not (equal (cdr $features) featurel))
		     (setq $features (cons '(mlist simp) 
					   (copy-top-level featurel ))))))
	     ((eq x '$post_eval_functions) (setq $post_eval_functions '((mlist)) ))
	     ((or (eq x t) (eq x '$all))
	      (setq $post_eval_functions '((mlist)))
	      (mapc #'kill1 (cdr $infolists))
	      (setq $ratvars '((mlist simp)) varlist nil genvar nil
		    checkfactors nil greatorder nil lessorder nil $gensumnum 0
		    $weightlevels '((mlist)) *ratweights nil $ratweights 
		    '((mlist simp))
		    tellratlist nil $dontfactor '((mlist)) $setcheck nil)
	      (killallcontexts))
	     ((setq z (assq x '(($clabels . $inchar) ($dlabels . $outchar)
				($elabels . $linechar))))
	      (mapc #'(lambda (y) (remvalue y '$kill))
		    (getlabels* (eval (cdr z)) nil)))
	     ((and (eq (ml-typep x) 'fixnum) (not (< x 0))) (remlabels x))
	     ((atom x) (kill1-atom x))
	     ((and (eq (caar x) 'mlist) (eq (ml-typep (cadr x)) 'fixnum)
		   (or (and (null (cddr x)) 
			    (setq x (append x (ncons (cadr x)))))
		       (and (eq (ml-typep (caddr x)) 'fixnum) 
			    (not (> (cadr x) (caddr x))))))
	      (let (($linenum (caddr x))) (remlabels (f- (caddr x) (cadr x)))))
	     ((setq z (mgetl (caar x) '(hashar array))) (remarrelem z x))
	     ((and (eq (caar x) '$allbut)
		   (not (dolist (u (cdr x)) 
			  (if (not (symbolp u)) (return t)))))
	      (let ((allbutl (cdr x))) (kill1 t)))
	     (t (improper-arg-err x '$kill))))
   nil))


;; Code to optionally group units by common unit

(defun unitmember (form list1)
   (cond ((equal (car list1) nil) nil)
         ((equal form (car list1)) t) 
	 (t (unitmember form (cdr list1)))))
   	 
(defun groupbyaddlisp (form)
    (cond ((or (not(notunitfree (car form))) (not(notunitfree (cadr form))))
            form)
    	  ((and (null (cddr form))(equal (meval (list '(mplus simp) (caddr (car form)) (list '(mtimes simp) -1 (caddr (cadr form))))) 0))
              (list (list '(mtimes) (meval (list '(mplus simp) (cadr (car form)) (cadr (cadr form)))) (caddr (car form)))))
	  ((null (cddr form)) form)
          ((equal (meval (list '(mplus simp) (caddr (car form)) (list '(mtimes simp) -1 (caddr (cadr form))))) 0)
	       (groupbyaddlisp (cons (list '(mtimes) (meval (list '(mplus simp) (cadr (car form)) (cadr (cadr form)))) (caddr (car form)))
	              (cddr form))))
	  (t (cons (list '(mtimes) (cadr (car form)) (caddr (car form))) (groupbyaddlisp (cdr form))))))	     
	   
(defun groupadd (form) 
   (cond ((and (not (atom form)) (notunitfree form))
           (let ((temp1 (groupbyaddlisp (cdr (nformat form)))))
           (cond ((or (not (equal (cdr temp1) nil)) (and (atom (cadr temp1)) (not (equal (cadr temp1) nil))))
                  (cons '(mplus) temp1))
		 ((equal (cdr temp1) nil) (car temp1))))) 
         (t form)))
    
;; Code to enable correct display of multiplication by units via nformat
(defun notunitfree (form)
  ;;returns t if expression contains units, nil otherwise
  (cond ((atom form) ($member form $allunitslist))
        ((null (car form)) nil)
  	((atom (car form))(or ($member (car form) $allunitslist)
			      (notunitfree (cdr form))))
	(t (or (notunitfree (cdr (car form)))
	       (notunitfree (cdr form))))))

(defun onlyunits (form)
  ;;returns t if expression contains only units, nil otherwise
  (cond ((null (car form)) t)
        ((atom (car form))(and ($member (car form) $allunitslist)
			      (onlyunits (cdr form))))
	(t (and (onlyunits (list (car (cdr (car form)))))
	       (onlyunits (cdr form))))))

(defun getunits (form)
  ;;returns a list containing all unit terms
  (cond ((null (cadr form)) '())
	((atom (cadr form)) 
	 (if ($member (cadr form) $allunitslist) 
	     (cons (cadr form) 
		   (getunits (cons (car form) (cdr (cdr form)))))
	     (getunits (cons (car form) (cdr (cdr form))))))
	(t
	 (if ($member (cadr (cadr form)) $allunitslist) 
	     (cons (cadr form) 
		   (getunits (cons (car form) (cdr (cdr form)))))
	     (getunits (cons (car form) (cdr (cdr form))))))))

(defun nonunits (form)
  ;;returns a list containing all non-unit terms
  (cond ((null (cadr form)) '())
	((atom (cadr form)) 
	 (if (not($member (cadr form) $allunitslist)) 
	     (cons (cadr form) 
		   (nonunits (cons (car form) (cdr (cdr form)))))
	     (nonunits (cons (car form) (cdr (cdr form))))))
	(t
	 (if (not($member (cadr (cadr form)) $allunitslist)) 
	     (cons (cadr form) 
		   (nonunits (cons (car form) (cdr (cdr form)))))
	     (nonunits (cons (car form) (cdr (cdr form))))))))

(defun unitmtimeswrapper (form)
   (setq form1 (mfuncall '$processunits form))
   (cond ((and (notunitfree form) (not(onlyunits (cdr form))))
	 (list '(mtimes) 
	       (cons '(mtimes simp) (nonunits form1))
	       (cons '(mtimes simp) (getunits form1))))
         ((onlyunits (cdr form)) (form-mtimes form))
         (t (form-mtimes form))))


(defmfun nformat (form)
  (cond ((atom form)
	 (cond ((and (numberp form) (minusp form)) (list '(mminus) (minus form)))
	       ((eq t form) (if in-p t '$true))
	       ((eq nil form) (if in-p nil '$false))
	       ((and displayp (car (assqr form aliaslist))))
	       ;;	       (($EXTENDP FORM)
	       ;;		(NFORMAT (transform-extends form)))
	       (t form)))
	((atom (car form))
	 form)
	((eq 'rat (caar form))
	 (cond ((minusp (cadr form))
		(list '(mminus) (list '(rat) (minus (cadr form)) (caddr form))))
	       (t (cons '(rat) (cdr form)))))
	((eq 'mmacroexpanded (caar form)) (nformat (caddr form)))
	((null (cdar form)) form)
	((eq 'mplus (caar form)) (form-mplus form))
	((eq 'mtimes (caar form)) (unitmtimeswrapper form))
	((eq 'mexpt (caar form)) (form-mexpt form))
	((eq 'mrat (caar form)) (form-mrat form))
	((eq 'mpois (caar form)) (nformat ($outofpois form)))
	((eq 'bigfloat (caar form))
	 (if (minusp (cadr form))
	     (list '(mminus) (list (car form) (minus (cadr form)) (caddr form)))
	     (cons (car form) (cdr form))))
	(t form)))
(defun testing1 (form)
   (destructuring-bind ((mplus) ((mtimes1) (val1) (temp1)) 
                                ((mtimes2) (val2) (temp2)) &rest more) form 
			(print val1)
			(print val2)
			(print temp1)
			(print temp2)
			))
