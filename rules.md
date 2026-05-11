---
name: Coding rule
---
  Ignore the TODO and README.md

  We are a high-bandwidth science and engineering team engaged in a continuous verbal partnership.
  We prioritize technical density and zero-redundancy,
  communicating exclusively through a strict hierarchy of descriptive headings and nested lists to ensure perfect auditory flow.
  We operate in a constant feedback loop: identifying one critical 'what-if' variable, executing, and refining.
  We follow existing s3backer C-style conventions.

  PROJECT GOAL: We are implementing s3backer-ttl using Temporal Offset Logic.

  DESIRED FUNCTIONS:  A work in progress.
  1. TIMEBASE: 
     - 64-bit monotonic counter (EMS = Elapsed_Mount_Seconds).
     - Initialized at 0 on mount. All TTL metrics are absolute timestamps relative to this 0-anchor.

  2. CONFIGURATION (struct block_cache_conf):
     - ttl_mode: bool (Default: false). If false, bypass all TTL logic and use standard LRU.
     - ttl_base: u_int (Default: 60).
     - ttl_bonus: u_int (Default: 30).
     - ttl_max_limit: u_int (Default: 3600).
     - DESIGN NOTE: These should be accessible for potential runtime adjustment.

  3. PER-CHUNK METADATA (struct cache_entry):
     - current_ttl: uint64 (Absolute timestamp: EMS + survival_offset).
     - max_ttl_offset: u_int (Duration: the current total survival credit allowed).

  4. ON-ACCESS LOGIC: (affects only CLEAN/CLEAN2 blocks)
     - If ttl_mode is enabled:
       - If New Block: 
           max_ttl_offset = ttl_base; 
           current_ttl = EMS + max_ttl_offset.
       - If Existing Block: 
           max_ttl_offset = min(max_ttl_offset + ttl_bonus, ttl_max_limit);
           current_ttl = EMS + max_ttl_offset.

  5. EVICTION PRIORITY:
     a. Stale Gate: current_ttl < EMS (Expired).
     b. Life Expectancy: Lowest absolute current_ttl (Closest to death).
     c. Survival Credit Used: Largest (max_ttl_offset - (current_ttl - EMS)).
     d. LRU: Chronological fallback.
