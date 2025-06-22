;; Constants
(define-constant FITNESS_POINT_POOL u2000000)
(define-constant BASE_WORKOUT_REWARD u15)
(define-constant STREAK_BONUS u5)
(define-constant MAX_STREAK_LEVEL u10)
(define-constant ERR_INVALID_WORKOUT u1)
(define-constant ERR_NO_FITNESS_POINTS u2)
(define-constant ERR_POOL_DEPLETED u3)
(define-constant BLOCKS_PER_FITNESS_CYCLE u1440)
(define-constant COMMITMENT_MULTIPLIER u3)
(define-constant MIN_COMMITMENT_DURATION u1152)
(define-constant EARLY_WITHDRAWAL_FEE u15)

;; Data Variables
(define-data-var total-fitness-points-distributed uint u0)
(define-data-var total-workout-sessions uint u0)
(define-data-var fitness-coordinator principal tx-sender)

;; Data Maps
(define-map athlete-workouts principal uint)
(define-map athlete-fitness-points principal uint)
(define-map workout-session-start principal uint)
(define-map athlete-streak principal uint)
(define-map athlete-last-workout principal uint)
(define-map athlete-committed-points principal uint)
(define-map athlete-commitment-start-block principal uint)

;; Public Functions

(define-public (start-workout-session (intensity uint))
  (let
    (
      (athlete tx-sender)
    )
    (asserts! (> intensity u0) (err ERR_INVALID_WORKOUT))
    (map-set workout-session-start athlete burn-block-height)
    (ok true)
  )
)

(define-public (finish-workout-session (intensity uint))
  (let
    (
      (athlete tx-sender)
      (start-block (default-to u0 (map-get? workout-session-start athlete)))
      (blocks-exercised (- burn-block-height start-block))
      (last-workout-block (default-to u0 (map-get? athlete-last-workout athlete)))
      (streak-level (default-to u0 (map-get? athlete-streak athlete)))
      (capped-streak (if (<= streak-level MAX_STREAK_LEVEL) streak-level MAX_STREAK_LEVEL))
      (reward-amount (+ BASE_WORKOUT_REWARD (* capped-streak STREAK_BONUS)))
    )
    (asserts! (and (> start-block u0) (>= blocks-exercised intensity)) (err ERR_INVALID_WORKOUT))
    (map-set athlete-workouts athlete (+ (default-to u0 (map-get? athlete-workouts athlete)) u1))
    (map-set athlete-fitness-points athlete (+ (default-to u0 (map-get? athlete-fitness-points athlete)) reward-amount))
    (if (< (- burn-block-height last-workout-block) BLOCKS_PER_FITNESS_CYCLE)
      (map-set athlete-streak athlete (+ streak-level u1))
      (map-set athlete-streak athlete u1)
    )
    (map-set athlete-last-workout athlete burn-block-height)
    (var-set total-workout-sessions (+ (var-get total-workout-sessions) u1))
    (var-set total-fitness-points-distributed (+ (var-get total-fitness-points-distributed) reward-amount))
    (asserts! (<= (var-get total-fitness-points-distributed) FITNESS_POINT_POOL) (err ERR_POOL_DEPLETED))
    (ok reward-amount)
  )
)

(define-public (redeem-fitness-rewards)
  (let
    (
      (athlete tx-sender)
      (point-balance (default-to u0 (map-get? athlete-fitness-points athlete)))
    )
    (asserts! (> point-balance u0) (err ERR_NO_FITNESS_POINTS))
    (map-set athlete-fitness-points athlete u0)
    (ok point-balance)
  )
)

;; Commitment Features

(define-public (commit-fitness-points (amount uint))
  (let
    (
      (athlete tx-sender)
    )
    (asserts! (> amount u0) (err ERR_INVALID_WORKOUT))
    (asserts! (>= (var-get total-fitness-points-distributed) amount) (err ERR_POOL_DEPLETED))
    (map-set athlete-committed-points athlete amount)
    (map-set athlete-commitment-start-block athlete burn-block-height)
    (var-set total-fitness-points-distributed (- (var-get total-fitness-points-distributed) amount))
    (ok amount)
  )
)

(define-public (withdraw-committed-points)
  (let
    (
      (athlete tx-sender)
      (committed-amount (default-to u0 (map-get? athlete-committed-points athlete)))
      (commitment-start-block (default-to u0 (map-get? athlete-commitment-start-block athlete)))
      (blocks-committed (- burn-block-height commitment-start-block))
      (penalty (if (< blocks-committed MIN_COMMITMENT_DURATION) (/ (* committed-amount EARLY_WITHDRAWAL_FEE) u100) u0))
      (final-amount (- committed-amount penalty))
    )
    (asserts! (> committed-amount u0) (err ERR_NO_FITNESS_POINTS))
    (map-set athlete-committed-points athlete u0)
    (map-set athlete-commitment-start-block athlete u0)
    (var-set total-fitness-points-distributed (+ (var-get total-fitness-points-distributed) final-amount))
    (ok final-amount)
  )
)

;; Read-Only Functions

(define-read-only (get-workout-count (user principal))
  (default-to u0 (map-get? athlete-workouts user))
)

(define-read-only (get-fitness-point-balance (user principal))
  (default-to u0 (map-get? athlete-fitness-points user))
)

(define-read-only (get-streak-level (user principal))
  (default-to u0 (map-get? athlete-streak user))
)

(define-read-only (get-fitness-platform-stats)
  {
    total-workout-sessions: (var-get total-workout-sessions),
    total-fitness-points-distributed: (var-get total-fitness-points-distributed)
  }
)

;; Private Functions

(define-private (is-fitness-coordinator)
  (is-eq tx-sender (var-get fitness-coordinator))
)
