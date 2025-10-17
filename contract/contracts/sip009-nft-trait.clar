(define-trait sip009-nft-trait
  (
    ;; Get the last token ID
    (get-last-token-id () (response uint uint))
    
    ;; Get token URI
    (get-token-uri (uint) (response (optional (string-ascii 256)) uint))
    
    ;; Get token owner
    (get-owner (uint) (response (optional principal) uint))
    
    ;; Transfer token
    (transfer (uint principal principal) (response bool uint))
  )
)
