% unit tests
function ok = TE_uff_init(~)

% run all initialization tests
try
    ok = ( ...
           test_sector_scan_mod() ...
        && test_wave_mod() ...
        && test_wave_init() ...
        );
catch
    ok = false;
end

    function pass = test_sector_scan_mod()
        % create two distinct objects
        s = uff.sector_scan;
        r = uff.sector_scan;

        % copy the second's source
        p = uff.point();
        p.copy(r.apex); % r.source == p
        
        % modify the first
        s.apex.xyz = rand([1,3]);
        
        % the second should remain unmodified
        pass = (all(r.apex.xyz == p.xyz));
    end

    function pass = test_wave_mod()
        % create two distinct objects
        u = uff.wave();
        v = uff.wave();
        
        % copy the second's source
        p = uff.point();
        p.copy(v.source);
        
        % modify the first
        u.source.xyz = rand([1,3]);
        
        % the second should remain unmodified
        pass = all(v.source.xyz == p.xyz);
    end

    function pass = test_wave_init()
        pass = true;
        for w = enumeration(uff.wavefront.spherical)'
            s = uff.point('xyz', rand([1,3]));
            c = rand;
            d = rand;
            
            % create object
            u = uff.wave(...
                'source', s, ...
                'delay', d, ...
                'sound_speed', c, ...
                'wavefront', w ...
                );
            
            % check that values were assigned
            pass = pass && (...
                all(u.source.xyz == s.xyz) ...
                && u.delay == d ...
                && u.sound_speed == c ...
                && u.wavefront == w ...
                );
        end
    end
end
