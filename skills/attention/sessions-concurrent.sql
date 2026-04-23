SELECT printf('PEAK_CONCURRENT: %d', MAX(cnt)) FROM (
  SELECT s1.id, COUNT(DISTINCT s2.id) AS cnt
  FROM session s1
  JOIN session s2 ON (
    s2.time_created <= s1.time_updated
    AND s2.time_updated >= s1.time_created
    AND s2.id != s1.id
    AND s2.title NOT LIKE '%subagent%'
    AND s2.directory NOT LIKE '%worktree%'
    AND (s2.time_updated - s2.time_created) / 60000 > 1
  )
  WHERE date(s1.time_created/1000,'unixepoch','localtime') = date('now','localtime')
    AND s1.title NOT LIKE '%subagent%'
    AND s1.directory NOT LIKE '%worktree%'
    AND (s1.time_updated - s1.time_created) / 60000 > 1
  GROUP BY s1.id
)
