function [flowField, p, GT] = Phantom_spinningDisk( setup, X, Y, Z ) % parameter structure p not used in this example

p.btfAZ = 90;
p.tubedepth = 0.015; %m
p.diameter = 0.003; %m
p.maxLineSpacing = 0.0001;
p.maxVel = 1.0; %m/s
p.minVel = 0.2; %m/s
p.pointsPerRound = 200;

if ~isempty(setup)
    fields = fieldnames(setup);
    for k=1:size(fields,1)
        if(isfield(p,fields{k}))
            p.(fields{k}) = setup.(fields{k});
        else
            disp([ fields{k} ' is not a valid parameter for this phantom type']);
        end
    end
end

origin = [0 0 p.tubedepth];
radTab = p.diameter/2:-p.maxLineSpacing:0;
vels = linspace(p.maxVel, 0, length( radTab) );
valInds = vels > p.minVel;
radTab = radTab( valInds);
vels = vels( valInds);

revolvSpeed = p.maxVel/(p.diameter*pi);

ctr = 1;
for kk = 1:length( radTab )
    time_max = 1/revolvSpeed;
    phasefact = exp( 1i* 2*pi*(0:p.pointsPerRound)/p.pointsPerRound );

    currtubepos = radTab(kk).*phasefact;
    currdepth = real( currtubepos);
    currxpos = imag( currtubepos);
    
    flowField(ctr).timetab = linspace(0, time_max, p.pointsPerRound+1);
    flowField(ctr).postab = [currxpos; zeros(1,p.pointsPerRound+1);  currdepth] + ...
        [0; 0; p.tubedepth];
    flowField(ctr).timetab = flowField(ctr).timetab.'; 
    flowField(ctr).postab = flowField(ctr).postab.';
    ctr = ctr + 1;
end

if nargin > 1,
    radPoints = sqrt( (Z(:)-p.tubedepth).^2+X(:).^2 );
    vecZ = Z(:)-p.tubedepth;
    vecX = X(:);
    velX = vecZ./(p.diameter/2).*p.maxVel;
    velZ = -vecX./(p.diameter/2).*p.maxVel;
    velX(radPoints > p.diameter/2 | radPoints < min(radTab) ) = NaN;
    velZ(radPoints > p.diameter/2 | radPoints < min(radTab)) = NaN;
    GT = cat(2, velX, zeros( size( velX) ), velZ);
end