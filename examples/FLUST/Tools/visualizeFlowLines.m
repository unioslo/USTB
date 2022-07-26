function visualizeFlowLines( flowField)
figure(100), hold on
maxY = 0;
for kk = 1:length( flowField)
    plot3( flowField(kk).postab(:,1), flowField(kk).postab(:,2), flowField(kk).postab(:,3), 'Linewidth', 2 );
    xlabel('X (m)'), ylabel('Y (m)'), zlabel('Z (m)')
    title('Flowlines')
    hold on;
    maxY = max( maxY, abs( flowField(kk).postab(:,2) ) );
end
grid on
if maxY == 0
    view([0 0]);
else
    view(3);
end
set( gca, 'ZDir', 'reverse');
axis equal tight
drawnow;