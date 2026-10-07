# Guess the Corr

Guess Pearson's *r* for scatter plots drawn in the shape of each letter, A to Z. Inspired by [Guess the Correlation](https://guessthecorrelation.com).

- `index.html` is the whole game: no build step. GitHub Pages serves it as-is.
- `supabase.sql` sets up the leaderboard table in Supabase (paste into the SQL Editor and run). Players sign in with a name; every guess is saved, guesses lock once made, and finished runs are ranked by mean squared error.

The Supabase URL and publishable key at the top of the script in `index.html` are public by design; row-level security and the trigger in `supabase.sql` limit what they can do.
