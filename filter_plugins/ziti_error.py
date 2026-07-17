def ziti_error_summary(stderr):
    """Extract the most useful line from ziti CLI stderr.

    Handles two observed shapes:
      A) 'Error: <text>' (+ optionally a repeated raw JSON HTTP body)
      B) JSON-lines structured logger output (one object per line),
         where the last line's 'msg'/'cause' is the actionable part.
    Falls back to raw stderr if neither shape matches.
    """
    import json

    if not stderr:
        return "(no error output captured)"

    lines = [l for l in stderr.splitlines() if l.strip()]
    if not lines:
        return "(no error output captured)"

    # Try JSON-lines (enrollment panics): use the last line's cause/msg
    for line in reversed(lines):
        try:
            obj = json.loads(line)
        except (ValueError, TypeError):
            continue
        if isinstance(obj, dict):
            cause = obj.get("cause")
            msg = obj.get("msg")
            if cause and msg:
                return "{0}: {1}".format(msg, cause)
            if msg:
                return msg

    # Fall back to first 'Error:' line (CLI-level failures)
    for line in lines:
        if line.startswith("Error:"):
            return line

    # Last resort: first non-empty line
    return lines[0]


class FilterModule(object):
    def filters(self):
        return {"ziti_error_summary": ziti_error_summary}
