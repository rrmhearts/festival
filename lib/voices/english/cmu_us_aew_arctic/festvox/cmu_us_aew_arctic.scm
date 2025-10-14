;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;-*-mode:scheme-*-
;;;                                                                       ;;
;;;                    Alan W Black and Kevin Lenzo                       ;;
;;;                         Copyright (c) 1998                            ;;
;;;                        All Rights Reserved.                           ;;
;;;                                                                       ;;
;;;  Permission is hereby granted, free of charge, to use and distribute  ;;
;;;  this software and its documentation without restriction, including   ;;
;;;  without limitation the rights to use, copy, modify, merge, publish,  ;;
;;;  distribute, sublicense, and/or sell copies of this work, and to      ;;
;;;  permit persons to whom this work is furnished to do so, subject to   ;;
;;;  the following conditions:                                            ;;
;;;   1. The code must retain the above copyright notice, this list of    ;;
;;;      conditions and the following disclaimer.                         ;;
;;;   2. Any modifications must be clearly marked as such.                ;;
;;;   3. Original authors' names are not deleted.                         ;;
;;;   4. The authors' names are not used to endorse or promote products   ;;
;;;      derived from this software without specific prior written        ;;
;;;      permission.                                                      ;;
;;;                                                                       ;;
;;;  THE AUTHORS OF THIS WORK DISCLAIM ALL WARRANTIES WITH REGARD TO      ;;
;;;  THIS SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY   ;;
;;;  AND FITNESS, IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY         ;;
;;;  SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES            ;;
;;;  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN   ;;
;;;  AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,          ;;
;;;  ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF       ;;
;;;  THIS SOFTWARE.                                                       ;;
;;;                                                                       ;;
;;;  This file is part "Building Voices in the Festival Speech            ;;
;;;  Synthesis System" by Alan W Black and Kevin Lenzo written at         ;;
;;;  Robotics Institute, Carnegie Mellon University, fall 98              ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;  A US English diphone voice based on KAL
;;;
;;;  Much of the front end is based on KED
;;;
;;;
;;	M Caisse 3/13/2023 Repurposed as frontend for cmu_us_aew_arctic Merlin voice

(defvar cmu_us_aew_arctic_dir (cdr (assoc 'cmu_us_aew_arctic voice-locations))
  "cmu_us_aew_arctic_dir
  The default directory for the cmu_us_aew_arctic front-end files")
(set! load-path (cons (path-append cmu_us_aew_arctic_dir "festvox/") load-path))

(require 'radio_phones)
(require_module 'UniSyn)

;;;  Set up the CMU lexicon (defined in lib/lexicons.scm)
(setup_cmu_lex)

(define (voice_cmu_us_aew_arctic)
"(voice_cmu_us_aew_arctic)
   Male U.S. English voice using Merlin DNN voice models."

  ;; Phone set
  ;;    See http://festvox.org/docs/manual-2.4.0/festival_12.html#Phonesets
  (voice_reset)
  (Parameter.set 'Language 'americanenglish)
  (require 'radio_phones)
  (Parameter.set 'PhoneSet 'radio)
  (PhoneSet.select 'radio)

  ;; Tokenization rules
  ;;   Defined in lib/token.scm. Tokenizes input for further processing.
  ;;   Handles numbers, punctuation, other non-alpha characters.
  ;;   This is handled by the Voice Server before sending the message string to 
  ;;   Festival, so may not do much with the string sent to it by RFTS.
  (set! token_to_words english_token_to_words)

  ;; POS tagger
  ;;   lib/pos.scm lists functions words in an associative array. The remainder are considered
  ;;   content words. Used to determine location of accents.
  ;;   See http://festvox.org/docs/manual-2.4.0/festival_16.html#POS-tagging
  (require 'pos)
  (set! pos_lex_name "english_poslex")
  (set! pos_ngram_name 'english_pos_ngram)
  (set! pos_supported t)
  (set! guess_pos english_guess_pos)   ;; need this for accents

  ;; Lexicon selection
  ;;    See http://festvox.org/docs/manual-2.4.0/festival_13.html#Lexicons
  (lex.select "cmu")
  ;; Add RFTS specific words to cmu lexicon
  (require 'dicts/cmu/rfts_addenda)
  ;; If user-specific pronunciations are desired, add an addenda file
  ;; to the voice directory and add a (require <file>) statement here.
  ;; (require './cmu_us_aew_arctic_addenda)

  ;; Apply rule to pronounce "'s" correctly.
  (set! postlex_rules_hooks (list postlex_apos_s_check))

  ;; Phrase prediction
  ;;    Predicts location and level of phrase boundaries.
  ;;    Break levels are BB (big break), B (break), NB (no break).
  ;;    See http://festvox.org/docs/manual-2.4.0/festival_17.html#Phrase-breaks
  (require 'phrase)
  (Parameter.set 'Phrase_Method 'prob_models)
  (set! phr_break_params english_phr_break_params)

  ;; Accent and tone prediction
  ;;   Inserts ToBI accents and boundary tones.
  ;;   The Festival front-end predicts the location of accents and tones.
  ;;   Merlin will assign F0 values based on prediction from accents in
  ;;   the linguistic input.
  ;;   See http://festvox.org/docs/manual-2.4.0/festival_18.html#Intonation,
  ;;   lib/tobi.scm
  (require 'tobi)
  (set! int_tone_cart_tree f2b_int_tone_cart_tree)
  (set! int_accent_cart_tree f2b_int_accent_cart_tree)

  ;; Festival F0 prediction and duration prediction are not used for Merlin
  ;; training or synthesis, but Festival requires that the methods be listed
  ;; for the voice. 
  (require 'f2bf0lr)
  (set! f0_lr_start f2b_f0_lr_start)
  (set! f0_lr_mid f2b_f0_lr_mid)
  (set! f0_lr_end f2b_f0_lr_end)
  (Parameter.set 'Int_Method Intonation_Tree)
  (set! int_lr_params
	'((target_f0_mean 105) (target_f0_std 14)
	  (model_f0_mean 170) (model_f0_std 34)))
  (Parameter.set 'Int_Target_Method Int_Targets_LR)
  ;; Duration prediction
  (require 'aewdurtreeZ)
  (set! duration_cart_tree kal_duration_cart_tree)
  (set! duration_ph_info kal_durs)
  (Parameter.set 'Duration_Method Duration_Tree_ZScores)
  (Parameter.set 'Duration_Stretch 1.1)

  (Parameter.set 'Synth_Method 'None)

  ;; Post-lexical rules
  ;;   Apply vowel reduction using CART data.
  ;;   I wonder if Merlin would handle this without Festival inputi,
  ;;   since it used a feature set available in the label file.
  ;;   TBD test this!!!
  (set! postlex_vowel_reduce_cart_tree 
	postlex_vowel_reduce_cart_data)

  (set! current-voice 'cmu_us_aew_arctic)
)

(proclaim_voice
 'cmu_us_aew_arctic
 '((language english)
   (gender male)
   (dialect foreign)
   (description
    "This voice provides an American English male voice using
     Merlin DNN synthesis method.  It uses the CMU Lexicon pronunciations. 
     Prosodic phrasing is provided by a statistically trained model using
     part of speech and local distribution of breaks.  Intonation is provided
     by a CART tree predicting ToBI accents.  F0 contour and duration are
     determined by the DNN model based on linguistic input and features
     in the label file")))

(provide 'cmu_us_aew_arctic)

