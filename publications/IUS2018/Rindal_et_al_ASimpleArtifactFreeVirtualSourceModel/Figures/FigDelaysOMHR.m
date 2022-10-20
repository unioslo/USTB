%
% Script som lager figur over geometri for bruk i oblig 1, H18
%


% "arrows" laget med funksjon arrow

% Figurstørrelse:
figure(1); clf; % subplot(4,4,[1:3 5:7 9:11])
axis([-5 5 -8 1]); Axis = axis;
hold on

axisColor = '-k';
% Definere fokuspkt
FokusRadius = 3;

        dx = 1; wx = dx - 0.05;
        dy = -.5; wy = dy;
        ElPos = -4:4;


%
% Har problemer med rekkefølge på det som plotter. Noen ganger kommer ting
% som plottes 'etterpå' under ting som allerede er plottet.
% Trikser derfor med rekkefølgen ting plottes

Rekkefolge = [4 7 3 5 6 8 9 1  ];
% Rekkefolge = [4  3 1 ];

% 1 == x-akse
% 2 == y-akse
% 3 == elementer (bokser)
% 4 == Indikere bakgrunn av område, blått, helt bakerst
% 5 == Indikere bakgrunn av område, rødt
% 6 == punkt P og vektorer, rød bakgrunn
% 7 == vektorer blå bakgrunn
% 8 == Fokus
% 9 == Aperture



for RF = Rekkefolge
    % RF, pause
    
    if RF==1
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % x-akse
        start = [-5, 5]'; stop = [0 0]';
        A = plot(start,stop,axisColor);
        set(A,'LineWidth',2);
    end
    
    if RF==2
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % y-akse
        start = [0, 0]; stop = [0, -8];
        A = plot(start,stop,axisColor);
        set(A,'LineWidth',2);
    end
    
    if RF==3
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Elementer
        %
        for ii = 1:length(ElPos)
            x0 = ElPos(ii)*dx;
            y0 = 0;
            E = fill(x0+[-wx/2 wx/2 wx/2 -wx/2 -wx/2], y0+[0 0 -wy -wy 0],'r');
            text(x0,y0-wy/2,int2str(ii),'HorizontalAlignment','center','VerticalAlignment','middle');
            
            ElColor = [0 200 0]/255;
            E.EdgeAlpha=0;
            E.FaceColor = ElColor;

            
            % extra dot
            plot(x0,y0,'k.','MarkerSize',20)
        end
    end
    
    if RF==4  % Plotte blått bakgrunnsområde
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Antall elementer som skal være med i Nikolov-figur
        NES= 2; % No. Elements Sektor
        
        % Stigningstall, sektor. Sektor strekker seg utenfor fokuspkt (se original)
        Ax = (FokusRadius*1.1) / (NES*dx);
        tmpFoc = -FokusRadius*0.9;
        
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Tegne sektor om center == element ##
        
        CentEl = 4;
        FillColor = [150 200 255]/255;
        E = fill([ElPos(CentEl)-NES*dx ElPos(CentEl)+NES*dx ElPos(CentEl) ElPos(CentEl)-NES*dx], ...
            [0 0 -Ax*NES*dx 0],'m');
        E.EdgeAlpha=0;
        E.FaceColor = FillColor;
        
        F = fill([(ElPos(1)-1)*dx ElPos(end)*dx  ElPos(CentEl) (ElPos(1)-1)*dx], ...
            tmpFoc+[-Ax*(ElPos(CentEl)-ElPos(1)+1)*dx -Ax*(ElPos(end)-ElPos(CentEl))*dx 0 -Ax*(ElPos(CentEl)-ElPos(1)+1)*dx],'m');
        F.EdgeAlpha = 0;
        F.FaceColor = FillColor;
        
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Tegne halvsirkler fra fokus
        %MaxVinkel = atan(NES*dx / FokusRadius);
        %nVinkler = 51;
        %Vinkler = linspace(-MaxVinkel, MaxVinkel, nVinkler);
        %for Rad = [-2 -1 1 2 4]
        %    plot(ElPos(CentEl)+Rad.*sin(Vinkler),-FokusRadius-Rad.*cos(Vinkler),'r')
        %end
    end
    
    
    if RF==5
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Antall elementer som skal være med i Nikolov-figur
        NES= 2; % No. Elements Sektor
        
        % Stigningstall, sektor. Sektor strekker seg utenfor fokuspkt (se original)
        Ax = (FokusRadius*1.1) / (NES*dx);
        tmpFoc = -FokusRadius*0.9;
        
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Tegne sektor om center == element 5
        
        CentEl = 5;
        FillColor = [255 150 150]/255;
        E = fill([ElPos(CentEl)-NES*dx ElPos(CentEl)+NES*dx ElPos(CentEl) ElPos(CentEl)-NES*dx], ...
            [0 0 -Ax*NES*dx 0],'m');
        E.EdgeAlpha=0;
        E.FaceColor = FillColor;
        
        uistack(E,'top');
        
        F = fill([ElPos(1)*dx ElPos(end)*dx  ElPos(CentEl) ElPos(1)*dx], ...
            tmpFoc+[-Ax*(ElPos(CentEl)-ElPos(1))*dx -Ax*(ElPos(end)-ElPos(CentEl))*dx  0 -Ax*(ElPos(CentEl)-ElPos(1))*dx],'m');
        F.EdgeAlpha = 0;
        F.FaceColor = FillColor;
        
        
        
        
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Tegne halvsirkler fra fokus
        MaxVinkel = atan(NES*dx / FokusRadius);
        nVinkler = 51;
        Vinkler = linspace(-MaxVinkel, MaxVinkel, nVinkler);
        for Rad = [-2 -1 1 2 4]
            plot(ElPos(CentEl)+Rad.*sin(Vinkler),-FokusRadius-Rad.*cos(Vinkler),'r')
        end
    end
    
    if RF==6
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Plotte pkt P og vektorer
        
        % Pkt P
        P = [1, -5];
        plot(P(1),P(2),'ok','MarkerSize',6);
        text(P(1)+.15,P(2),'$\vec{p}$','FontSize',16,'Interpreter','latex');
        
        
        % Fra senterelemet til fokus
        start = [0, 0]; stop = [0, -FokusRadius];
        A1 = arrow(start,stop,8);  % my_arrow feiler! Havner under bakgrunn
        set(A1,'LineWidth',2);
        set(A1,'EdgeColor','r');
        set(A1,'FaceColor','r');
        text(0.1,-1.3,'$\vec{x}_k$','FontSize',16,'Interpreter','latex')
        
        
        % Fra fokus til P
        start = [0, -FokusRadius]; stop = P;
        A2 = my_arrow(start,stop,8);
        set(A2,'LineWidth',2);
        set(A2,'EdgeColor','r');
        set(A2,'FaceColor','r');
        text(0.5,-3.5,'$\vec{v}_k$','FontSize',16,'Interpreter','latex')
        
        % Fra P til ElPos(8)
        start = P; stop = [ElPos(8), 0];
        A3 = my_arrow(start,stop,8);
        set(A3,'LineWidth',2);
        set(A3,'EdgeColor','k');
        set(A3,'FaceColor','k');
        text(ElPos(8),-0.3,'$\vec{x}_j$','FontSize',16,'Interpreter','latex')
        
        
        % HACK Flytte blå pil på topp også i dette plottet
        if exist('A2x')
            uistack(A2x,'top');
            uistack(A2,'top');
        end

    end
    
    if RF==7
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Plotte vektorer på blå bakgrunn
        
        % Pkt P
        P = [1, -5];
        % plot(P(1),P(2),'ok','MarkerSize',6);
        %text(P(1)+.15,P(2),'$\vec{p}$','FontSize',16,'Interpreter','latex');
        
        % Fra senterelemet til fokus
        start = [-1, -Ax*dx]; stop = [-1, -FokusRadius];
        A1x = arrow(start,stop,8);  % my_arrow feiler! Havner under bakgrunn
        set(A1x,'LineWidth',2);
        set(A1x,'EdgeColor','b');
        set(A1x,'FaceColor','b');
        % text(0.1,-1.3,'$\vec{x}_k$','FontSize',16,'Interpreter','latex')
        
        
        % Fra fokus til P
        start = [-1, -FokusRadius]; stop = P;
        A2x = my_arrow(start,stop,8);
        set(A2x,'LineWidth',2);
        set(A2x,'EdgeColor','b');
        set(A2x,'FaceColor','b');
        % text(0.5,-3.5,'$\vec{v}_k$','FontSize',16,'Interpreter','latex')
        
        
    end
    
    if RF==8
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Indikere fokus
        plot([0.5 ElPos(end)],-FokusRadius*[1 1],'--')
        start = [ElPos(end)-dx/2 0]; stop = [ElPos(end)-dx/2 -FokusRadius];
        A3 = my_arrow(start,stop,8,'Ends','both');
        set(A3,'LineWidth',2);
        set(A3,'EdgeColor','k');
        set(A3,'FaceColor','k');
        text(ElPos(end)-dx/4,-FokusRadius/2,'$F$','FontSize',16,'Interpreter','latex')
    end
    
    if RF==9
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Indikere aperture
        plot([ElPos(CentEl)-NES*dx ElPos(CentEl)-NES*dx],[.5 1],'-')
        plot([ElPos(CentEl)+NES*dx ElPos(CentEl)+NES*dx],[.5 1],'-')
        start = [ElPos(CentEl)-NES*dx 0.75]; stop = [ElPos(CentEl)+NES*dx .75];
        A3 = my_arrow(start,stop,8,'Ends','both');
        set(A3,'LineWidth',2);
        set(A3,'EdgeColor','k');
        set(A3,'FaceColor','k');
        text(ElPos(CentEl),1,'$D_a$','FontSize',16, ...
            'HorizontalAlignment','center','Interpreter','latex')
        
    end
    
    
    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end
%
%

axis tight;
axis(Axis);
axis equal
%set(gca,'XColor','none')
%set(gca,'YColor','none')
set(gca,'Visible','off');
print -deps2c Nikolov.eps
%






