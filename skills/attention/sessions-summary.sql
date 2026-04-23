SELECT printf('TOTAL_USER_MESSAGES: %d', COALESCE(SUM(user_msgs), 0))
FROM (
  SELECT COUNT(CASE WHEN json_extract(m.data, '$.role') = 'user' THEN 1 END) AS user_msgs
  FROM session s
  JOIN message m ON m.session_id = s.id
  WHERE date(s.time_created/1000,'unixepoch','localtime') = date('now','localtime')
    AND s.title NOT LIKE '%subagent%'
    AND s.directory NOT LIKE '%worktree%'
    AND (s.time_updated - s.time_created) / 60000 > 1
  GROUP BY s.id
  HAVING user_msgs > 1
)
