# Experience curve comparison: old vs new (levels 1–50)

**Old system:** First level = 1 XP, then +5 per level → XP for level L = 1 + (L−1)×5  

**New system:**
- **1:** 1 XP
- **2–6:** Easier (3, 6, 9, 12, 15 per level)
- **7–12:** Same-ish as old (30, 35, 40, 45, 50, 55)
- **13–29:** Gently harder (ramp from 65 to 155)
- **30+:** Exponential starting at 1.10×, gentler every 3 levels (min 1.04×); level 30 step = 170.5 (no double level-up)

---

## Per-level XP (XP needed to go from this level to the next)

| Level | Old (XP for next) | New (XP for next) |
|------:|------------------:|------------------:|
| 1 | 1 | 1 |
| 2 | 6 | 3 |
| 3 | 11 | 6 |
| 4 | 16 | 9 |
| 5 | 21 | 12 |
| 6 | 26 | 15 |
| 7 | 31 | 30 |
| 8 | 36 | 35 |
| 9 | 41 | 40 |
| 10 | 46 | 45 |
| 11 | 51 | 50 |
| 12 | 56 | 55 |
| 13 | 61 | 65 |
| 14 | 66 | 70.6 |
| 15 | 71 | 76.2 |
| 16 | 76 | 81.9 |
| 17 | 81 | 87.5 |
| 18 | 86 | 93.1 |
| 19 | 91 | 98.8 |
| 20 | 96 | 104.4 |
| 21 | 101 | 110 |
| 22 | 106 | 115.6 |
| 23 | 111 | 121.2 |
| 24 | 116 | 126.9 |
| 25 | 121 | 132.5 |
| 26 | 126 | 138.1 |
| 27 | 131 | 143.8 |
| 28 | 136 | 149.4 |
| 29 | 141 | 155 |
| 30 | 146 | 170.5 |
| 31 | 151 | 187.6 |
| 32 | 156 | 206.3 |
| 33 | 161 | 226.9 |
| 34 | 166 | 245.1 |
| 35 | 171 | 264.7 |
| 36 | 176 | 285.9 |
| 37 | 181 | 303.0 |
| 38 | 186 | 321.2 |
| 39 | 191 | 340.5 |
| 40 | 196 | 354.1 |
| 41 | 201 | 368.3 |
| 42 | 206 | 383.0 |
| 43 | 211 | 398.3 |
| 44 | 216 | 414.2 |
| 45 | 221 | 430.8 |
| 46 | 226 | 448.0 |
| 47 | 231 | 466.0 |
| 48 | 236 | 484.6 |
| 49 | 241 | 504.0 |
| 50 | 246 | 524.2 |

---

## Cumulative total XP (total XP needed to reach this level from level 1)

| Level | Old (total XP) | New (total XP) |
|------:|---------------:|---------------:|
| 2 | 1 | 1 |
| 5 | 34 | 19 |
| 6 | 55 | 31 |
| 7 | 81 | 46 |
| 10 | 189 | 151 |
| 12 | 286 | 246 |
| 13 | 342 | 301 |
| 15 | 469 | 437 |
| 20 | 874 | 874 |
| 25 | 1,404 | 1,452 |
| 29 | 1,918 | 2,016 |
| 30 | 2,059 | 2,171 |
| 31 | 2,205 | 2,342 |
| 35 | 2,839 | 3,207 |
| 40 | 3,744 | 4,723 |
| 45 | 4,774 | 6,641 |
| 50 | 5,929 | 8,974 |

---

## Summary

- **1–6:** New is easier (e.g. level 5 total: 19 vs 34; level 6: 31 vs 55).
- **7–12:** About the same (e.g. level 10: 151 vs 189; level 12: 246 vs 286).
- **13–30:** New is gently harder (e.g. level 20 total: 874 vs 874; by 30: 2,171 vs 2,059).
- **30+:** Exponential starts at 1.10×, gets gentler every 3 levels (min 1.04×). Level 30→31 is 170.5 (no double level-up). By level 50, new total is 8,974 vs old 5,929.

Overall: earlier bands unchanged; post-30 is still harder than old but less steep than the previous 1.12× curve thanks to the gentler scaling.
