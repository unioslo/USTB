%
% Script som lager figur over geometri for bruk i oblig 1, H18
%


% "arrows" laget med funksjon arrow

% Figurstørrelse:
figure(1); clf; % subplot(4,4,[1:3 5:7 9:11])
axis([-4 4 -6 1]); Axis = axis;
hold on

axisColor = '-k';
% Definere fokuspkt
FokusRadius = 4;

dx = 1; wx = dx - 0.05;
dy = -.5; wy = dy;
ElPos = -3:3;


%
% Har problemer med rekkefølge på det som plotter. Noen ganger kommer ting
% som plottes 'etterpå' under ting som allerede er plottet.
% Trikser derfor med rekkefølgen ting plottes

Rekkefolge = [5 3 1 2 8 9 6 7];
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
        start = [-3.5, 3.5]'; stop = [0 0]';
        A = plot(start,stop,axisColor);
        set(A,'LineWidth',2);
    end
    
%     if RF==2
%         % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%         % y-akse
%         start = [0, 0]; stop = [0, -6];
%         A = plot(start,stop,axisColor);
%         set(A,'LineWidth',2);
%     end
    
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
    
    
    
    if RF==5
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Antall elementer som skal være med i Nguyen-figur
        NES= 2; % No. Elements Sektor
        
        % Stigningstall, sektor. Sektor strekker seg utenfor fokuspkt (se original)
        % Ax = (FokusRadius*1.1) / (NES*dx);
        % tmpFoc = -FokusRadius*0.9;
        Ax = (FokusRadius) / (NES*dx);
        tmpFoc = -FokusRadius;
        
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Tegne sektor om center == element 5
        
        CentEl = 4;
        FillColor = zeros(3,4);
        FillColor(:,1) = [255 150 150]/255;
        FillColor(:,2) = [255 150 150]/255;%[150 200 255]/255;55;
        FillColor(:,3) = [1 1 1];%[100 230 100]/255;
        FillColor(:,4) = [1 1 1];%[180 200 0]/255;55;
        
        E = fill([ElPos(CentEl)-NES*dx ElPos(CentEl)+NES*dx ElPos(CentEl) ElPos(CentEl)-NES*dx], ...
            [0 0 -Ax*NES*dx 0],'m');
        E.EdgeAlpha=0;
        E.FaceColor = FillColor(:,1);
        
        F = fill([ElPos(1)*dx ElPos(end)*dx  ElPos(CentEl) ElPos(1)*dx], ...
            tmpFoc+[-Ax*(ElPos(CentEl)-ElPos(1))*dx -Ax*(ElPos(end)-ElPos(CentEl))*dx  0 -Ax*(ElPos(CentEl)-ElPos(1))*dx],'m');
        F.EdgeAlpha = 0;
        F.FaceColor = FillColor(:,2);
        
        
        G = fill([ElPos(CentEl)+NES*dx (.5+ElPos(end))*dx (.5+ElPos(end))*dx  ElPos(CentEl)+(6+tmpFoc)/Ax*dx ElPos(CentEl) ElPos(CentEl)+NES*dx], ...
            [0 0 -6 -6 -FokusRadius 0],'m');
        G.EdgeAlpha = 0;
        G.FaceColor = FillColor(:,3);

        H = fill([ElPos(CentEl)-NES*dx (-.5+ElPos(1))*dx (-.5+ElPos(1))*dx  ElPos(CentEl)-(6+tmpFoc)/Ax*dx ElPos(CentEl) ElPos(CentEl)-NES*dx], ...
            [0 0 -6 -6 -FokusRadius 0],'m');
        H.EdgeAlpha = 0;
        H.FaceColor = FillColor(:,4);
        
        
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Tegne halvsirkler fra fokus
        %MaxVinkel = atan(NES*dx / FokusRadius);
        %nVinkler = 51;
        %Vinkler = linspace(-MaxVinkel, MaxVinkel, nVinkler);
        %for Rad = [-2 -1 1 2 4]
        %    plot(ElPos(CentEl)+Rad.*sin(Vinkler),-FokusRadius-Rad.*cos(Vinkler),'r')
        %end
    end
    
    if RF==6
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Plotte pkt P og vektorer
        
        % Pkt P
        P = [0.7, -3.5];
        plot(P(1),P(2),'ok','MarkerSize',6);
        text(P(1)+.2,P(2),'$\vec{p}$','FontSize',16, ...
            'HorizontalAlignment','left','Interpreter','latex');
        
        
%         % Fra senterelemet til fokus
%         start = [0, 0]; stop = [0, -FokusRadius];
%         A1 = arrow(start,stop,8);  % my_arrow feiler! Havner under bakgrunn
%         set(A1,'LineWidth',2);
%         set(A1,'EdgeColor','r');
%         set(A1,'FaceColor','r');
%         text(0.1,-1.3,'$\vec{x}_k$','FontSize',16,'Interpreter','latex')
        
        
        % Fra El til Fokus
        %start = [ElPos(CentEl)-NES*dx, 0]; stop = [0 -FokusRadius];
        %A2 = my_arrow(start,stop,8);
        %set(A2,'LineWidth',2);
        %set(A2,'EdgeColor','b');
        %set(A2,'FaceColor','b');
        %text(ElPos(3),-3.0,'$R_0$','FontSize',16,'Interpreter','latex')
        
    

        % Fra El til P
        %start = [ElPos(CentEl)-NES*dx, 0]; stop = P;
        %A2 = my_arrow(start,stop,8);
        %set(A2,'LineWidth',2);
        %set(A2,'EdgeColor','r');
        %set(A2,'FaceColor','r');
        %text(ElPos(3),-1.0,'$R_2$','FontSize',16,'Interpreter','latex')
        
        
        A = [P(1), -FokusRadius-Ax*(P(1))];
        plot(A(1),A(2),'ok','MarkerSize',6);
        text(A(1)-.2,A(2),'$A$','FontSize',16, ...
            'HorizontalAlignment','right','Interpreter','latex');

        B = [P(1), -FokusRadius+Ax*(P(1))];
        plot(B(1),B(2),'ok','MarkerSize',6);
        text(B(1)-.2,B(2),'$B$','FontSize',16, ...
            'HorizontalAlignment','right','Interpreter','latex');

        plot([A(1) B(1)], [A(2) B(2)])
        
        
%         % Fra P til ElPos(6)
%         start = P; stop = [ElPos(CentEl)+NES*dx, 0];
%         A3 = my_arrow(start,stop,8);
%         set(A3,'LineWidth',2);
%         set(A3,'EdgeColor','r');
%         set(A3,'FaceColor','r');
%         text(ElPos(CentEl)+NES*dx,-1.3,'$R_1$','FontSize',16, ...
%             'HorizontalAlignment','right','Interpreter','latex')

        
%         % Fra Fokuspunkt til ElPos(6)
%         start = [ElPos(CentEl), -FokusRadius]; stop = P; 
%         A3 = my_arrow(start,stop,8);
%         set(A3,'LineWidth',2);
%         set(A3,'EdgeColor','b');
%         set(A3,'FaceColor','b');
%         text(0.5,-FokusRadius,'$a$','FontSize',16, ...
%             'HorizontalAlignment','right', ...
%             'VerticalAlignment','baseline','Interpreter','latex')
        
        
        % Skrive på områder
        
         text(-2,-5,'(IV)','FontSize',18)
         text(2,-5,'(II)','FontSize',18)
         text(-.6,-5.5,'(III)','FontSize',18)
         text(.4,-.5,'(I)','FontSize',18)
        
        
        %         
%         
%         % HACK Flytte blå pil på topp også i dette plottet
%         if exist('A2x')
%             uistack(A2x,'top');
%             uistack(A2,'top');
%         end

    end
    
    if 0%RF==7
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Plotte vinkler:
        
        % alpha, åpningsvinkel
        
        MaxVinkel = atan(NES*dx / FokusRadius);
        nVinkler = 51;
        Vinkler = linspace(-MaxVinkel, MaxVinkel, nVinkler);
        for Rad = [.6]
            plot(ElPos(CentEl)+Rad.*sin(Vinkler),-FokusRadius-Rad.*cos(Vinkler),'r')
        end
        text(ElPos(CentEl)-.1,-FokusRadius-Rad,'$\alpha$','FontSize',14, ...
            'HorizontalAlignment','right', ...
            'VerticalAlignment','top','Interpreter','latex')

        % theta, mellom P og (negativ) y-akse
        
        Pvec = [P(1) P(2)+FokusRadius]; Pvec = Pvec / norm(Pvec);
        Yvec = [0 1];
        
        MaxVinkel = acos(Pvec * Yvec');
        nVinkler = 51;
        Vinkler = linspace(-0, MaxVinkel, nVinkler);
        for Rad = [.6]
            plot(ElPos(CentEl)+Rad.*sin(Vinkler),-FokusRadius+Rad.*cos(Vinkler),'r')
        end
        text(ElPos(CentEl)+.1,-FokusRadius+Rad,'$\theta$','FontSize',14, ...
            'HorizontalAlignment','left', ...
            'VerticalAlignment','bottom','Interpreter','latex')


        
    end
    
    if RF==8
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Indikere fokus
        plot([-0.5 ElPos(1)],-FokusRadius*[1 1],'--')
        start = [ElPos(1)+dx/2 0]; stop = [ElPos(1)+dx/2 -FokusRadius];
        A3 = my_arrow(start,stop,8,'Ends','both');
        set(A3,'LineWidth',2);
        set(A3,'EdgeColor','k');
        set(A3,'FaceColor','k');
        text(ElPos(1)+dx/4,-FokusRadius/2,'$F$','FontSize',16,...
            'HorizontalAlignment','right','Interpreter','latex')
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


% grid on
axis tight
axis(Axis);
axis equal
set(gca,'XColor','none')
set(gca,'YColor','none')
 %set(gca,'Visible','off');
 print -deps2c Nguyen_edit.eps
%






