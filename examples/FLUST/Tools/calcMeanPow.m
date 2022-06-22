function powEst = calcMeanPow( realTab, GT)
GTmask = ~isnan( sum( GT, 2) );
realTab_rsh = reshape( realTab, [prod( size( realTab, [1 2]) ) prod( size( realTab, [3 4 5] ) )] );
powEst = mean( sum( abs( realTab_rsh(GTmask,:) ).^2, 1)./sum(GTmask(:) ) );
end

