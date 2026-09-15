class_name FrontierContentTextIdentity
extends RefCounted
## Preserve exact content identities for the reviewed punctuation-only revision.
## Unknown digests pass through unchanged, so gameplay/data edits still fail old validation.
static var _pairs: Dictionary={}
static func canonical(value: Dictionary) -> String:
 return identity("canonical",FrontierUniverse.fingerprint(value))
static func raw(source: String) -> String:
 return identity("raw",source.sha256_text())
static func identity(kind: String,digest: String) -> String:
 if _pairs.is_empty():_pairs=JSON.parse_string(FileAccess.get_file_as_string("res://data/text_identity_compatibility.json"))
 return _pairs[kind].get(digest,digest)
