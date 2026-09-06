function slug = website_slug_for_dataset(filename)
%WEBSITE_SLUG_FOR_DATASET  Stable PNG basename for website (matches Python build script).
%
%   SLUG = WEBSITE_SLUG_FOR_DATASET('foo.uff')  ->  'foo_<md5hex[:10]>'
%
%   Must stay in sync with website/scripts/build_datasets_page.py (slug function).

if ~endsWith(filename, '.uff', 'IgnoreCase', true)
    filename = [filename '.uff'];
end
[~, base] = fileparts(filename);
hash10 = md5_hex_prefix(base, 10);
safe = regexprep(base, '[^a-zA-Z0-9_.-]', '_');
if numel(safe) > 40
    safe = safe(1:40);
end
slug = sprintf('%s_%s', safe, hash10);
end

function out = md5_hex_prefix(str, n)
% MD5 of UTF-8 bytes of STR; first N hex chars (must match Python hashlib.md5).
import java.security.MessageDigest
md = MessageDigest.getInstance('MD5');
jb = md.digest(uint8(char(str)));
hex = '';
for k = 1:length(jb)
    x = int32(jb(k));
    if x < 0
        x = x + 256;
    end
    hex = [hex sprintf('%02x', x)]; %#ok<AGROW>
end
hex = lower(hex);
out = hex(1:min(n, numel(hex)));
end
