SELECT
  s.title,
  replace(s.directory, '/Users/athal/code/', '') AS repo,
  (s.time_updated - s.time_created) / 60000 AS duration_min,
  COUNT(CASE WHEN json_extract(m.data, '$.role') = 'user' THEN 1 END) AS user_messages,
  datetime(s.time_created/1000,'unixepoch','localtime') AS started
FROM session s
LEFT JOIN message m ON m.session_id = s.id
WHERE date(s.time_created/1000,'unixepoch','localtime') = date('now','localtime')
  AND s.title NOT LIKE '%subagent%'
  AND s.directory NOT LIKE '%worktree%'
  AND (s.time_updated - s.time_created) / 60000 > 1
GROUP BY s.id
HAVING user_messages > 1
ORDER BY user_messages DESC
