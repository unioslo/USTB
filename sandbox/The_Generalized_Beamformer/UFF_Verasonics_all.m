%% Reading data from an UFF file recorded with the Verasonics CPWC_L7 example
clear all;
close all;

%% Checking the file is in the path
% data location
url = tools.zenodo_dataset_files_base();
% if not found data will be downloaded from here

% Order matches Fig. 5 in the paper: (a) plane, (b) diverging,
% (c) single diverging element (STA), (d) focused.
all_filenames{1}='L7_CPWC_TheGB.uff'; selected_tx(1) = 1;  tag{1} = 'PW';  tag_title{1} = 'Plane';
all_filenames{2}='L7_DW_TheGB.uff';   selected_tx(2) = 1;  tag{2} = 'DW';  tag_title{2} = 'Diverging';
all_filenames{3}='L7_STA_TheGB.uff';  selected_tx(3) = 32; tag{3} = 'STA'; tag_title{3} = 'Single Element Diverging';
all_filenames{4}='L7_FI_TheGB.uff';   selected_tx(4) = 20; tag{4} = 'FI';  tag_title{4} = 'Focused';

% Common display settings so the two rows of Fig. 5 are identical in size.
fig_position   = [638 434 480 520]; % aspect matched to scan (~30 mm x 47 mm) + label margin
dynamic_range  = 60;                % dB, common color scale for all panels

% Make sure the output folders exist before saving (saveas does not create them).
output_dirs = {'figures/single_tx_illustrations', ...
               'figures/compounded_images', ...
               'figures/DelayCalculation'};
for d = 1:numel(output_dirs)
    if ~exist(output_dirs{d}, 'dir')
        mkdir(output_dirs{d});
    end
end

b_data_compare = uff.beamformed_data();

for f = 1:length(all_filenames)
    filename = all_filenames{f};
    tools.download(filename, url, data_path);
    channel_data=uff.read_object([data_path filesep filename],'/channel_data');
    channel_data.N_frames = 1; %Only reconstruct one frame
    % Use sound speed stored in the UFF file (TheGB phantom ~1540 m/s).
   
    if contains(filename,'DW') || contains(filename,'FI')
        offset = eps;
        for seq = 1:channel_data.N_waves
            channel_data.sequence(seq).sound_speed = channel_data.sound_speed;
            %channel_data.sequence(seq).delay = channel_data.sequence(seq).delay + channel_data.sequence.t0_origin;
            channel_data.sequence(seq).delay
        end
    end

    scan=uff.linear_scan();
    scan.x_axis = linspace(channel_data.probe.x(1),channel_data.probe.x(end),512).';
    scan.z_axis = linspace(3e-3,50e-3,512).';
    scan.plot();
    title('Linear Scan');
    %saveas(gcf,'figures/linear_scan.png')
    %%
    %
    % and beamform
    mid=midprocess.das();
    mid.dimension = dimension.receive;
    mid.channel_data=channel_data;
    mid.scan=scan;
    if contains(filename,'FI')
        MLA = scan.N_x_axis/channel_data.N_waves;
        mid.spherical_transmit_delay_model = spherical_transmit_delay_model.hybrid;
        mid.pw_margin = 2/1000;
        mid.transmit_apodization.window=uff.window.tukey25;
        mid.transmit_apodization.f_number = 2.5;
        mid.transmit_apodization.MLA = MLA;
        mid.transmit_apodization.MLA_overlap = MLA;
        mid.transmit_apodization.minimum_aperture = [2.5e-03 2.5e-03];
    else
        mid.transmit_apodization.window=uff.window.none;
        mid.transmit_apodization.f_number=1.7;
    end

    mid.receive_apodization.window=uff.window.hamming;
    mid.receive_apodization.f_number=1.7;
    b_data_single_tx=mid.go();

    b_data = uff.beamformed_data(b_data_single_tx);
    b_data.data = reshape(b_data.data,size(b_data.data,1),1,1,size(b_data.data,3)); %Hack to just plot one transmit, make the transmit Frames...

    %%
%     fig_handle = figure();clf;
%     channel_data.probe.plot(fig_handle);hold on;
%     channel_data.sequence(selected_tx(f)).source.plot(fig_handle);
%     view(30,30)
    %% Illustrate t0 compensation
    single_tx_images = b_data.get_image();

    fig = figure;clf;
    subplot(5,1,1);hold all;
    if contains(filename,'STA')
        active_elements = zeros(1,128);
        active_elements(selected_tx(f)) = 1;
        plot(active_elements,'*')
        xlim([1 128]);xlabel('Elements');
        xlabel('Elements');title('Transmitting Element');%ylabel(["Active Elements"])
    elseif contains(filename,'FI')
        %% Illustrate t0 compensation
        transmit_delays = channel_data.sequence(selected_tx(f)).delay_values;
        transmit_delays(50:end) = transmit_delays(49);

        plot(transmit_delays.*10^6,'HandleVisibility','off','LineWidth',2);hold on;
        plot(channel_data.sequence(selected_tx(f)).delay_values.*10^6,'HandleVisibility','off','LineWidth',2)
        plot(49,transmit_delays(49).*10^6,'o','DisplayName','Conventional t_0','LineWidth',2);hold on;
        plot(64,channel_data.sequence(selected_tx(f)).delay_values(end/2)*10^6,'o','DisplayName','Generalized t_0','LineWidth',2)
        xlim([1 128]);xlabel('Elements');
        xlabel('Elements');ylabel(["Delay [ms]"]);title('Transmit Wavefront Delay');
    else
        plot(channel_data.sequence(selected_tx(f)).delay_values*10^6,'HandleVisibility','off','LineWidth',2)
        plot([channel_data.sequence(selected_tx(f)).delay_values+abs(min(channel_data.sequence(selected_tx(f)).delay_values))]*10^6,'HandleVisibility','off','LineWidth',2)
        plot(channel_data.N_elements,[channel_data.sequence(selected_tx(f)).delay_values(end)+abs(min(channel_data.sequence(selected_tx(f)).delay_values))]*10^6,'o','DisplayName','Conventional t_0','LineWidth',2)
        plot(channel_data.N_elements/2,channel_data.sequence(selected_tx(f)).delay_values(end/2)*10^6,'ro','DisplayName','Generalized t_0','LineWidth',2)
        xlabel('Elements');ylabel(["Delay [ms]"]);title('Transmit Wavefront Delay');
    end
    set(gca,'FontSize',13)
    axis tight
    legend show

    b_data.plot(subplot(5,1,[2:5]),['Single ',tag_title{f},' Transmit Image'],[],[],[],[selected_tx(f)]);
    colorbar off
    set(gcf,'Position',[659 87 581 891])
    % NOTE: the figure above (delay inset + image) is kept for reference only.

    % ----- Standalone single-transmit B-mode image (Fig. 5 top row) -----
    % Saved with the SAME figure size, color scale and axis labels as the
    % coherent-compounded image below. Colorbar included on each panel.
    %
    % NB: plot into an explicit axes handle (not a figure handle) so USTB does
    % NOT add the multi-frame slider uicontrol, which would make saveas/print
    % fail with "UI components are not supported".
    fig_tx = figure('Position',fig_position);
    ax_tx  = axes(fig_tx);
    b_data.plot(ax_tx,'',dynamic_range,[],[],[selected_tx(f)]);
    caxis(ax_tx,[-dynamic_range 0]);
    save_fig5_panel(fig_tx, ax_tx, ...
        ['figures/single_tx_illustrations/',tag{f},'_redone.eps'], ...
        true, true, ['(',char('a'+f-1),')']);  % top row: (a)-(d)

    %%
    b_data_illustrate_tx_delay = uff.beamformed_data(b_data);
    b_data_illustrate_tx_delay.data = mid.transmit_delay(:,selected_tx(f))*10^6;
    b_data_illustrate_tx_delay.plot([],['Transmit Distance'],[],['none']);
    title(['Transmit Distance']);
    colormap jet;
    cb = colorbar(); 
    ylabel(cb,'Distance [mm]','FontSize',12)
    %%
    fig = figure()
    b_data_illustrate_rx_delay = uff.beamformed_data(b_data);
    b_data_illustrate_rx_delay.data = mid.receive_delay(:,64)*10^6;
    b_data_illustrate_rx_delay.plot(fig,['Receive  Distance'],[],['none']);
    title(['Receive  Distance']);
    colormap jet;
    cb = colorbar
    ylabel(cb,'Distance [mm]','FontSize',12)
    saveas(fig,['figures/DelayCalculation/rx_64.png'])

    %% Coherent Compounding
    cc = postprocess.coherent_compounding();
    cc.input = b_data_single_tx;
    b_data_CC_postprocess = cc.go();

    % Compensate for different number of TX in area for FI
    if contains(filename,'FI')
        tx_comp = sum(mid.transmit_apodization.data,2);
        b_data_CC_postprocess.data = b_data_CC_postprocess.data.*(1./tx_comp);
    end
    fig_cc = figure('Position',fig_position);
    ax_cc  = axes(fig_cc);
    b_data_CC_postprocess.plot(ax_cc,'',dynamic_range);
    caxis(ax_cc,[-dynamic_range 0]);
    save_fig5_panel(fig_cc, ax_cc, ...
        ['figures/compounded_images/',tag{f},'_compounded_redone.eps'], ...
        true, true, ['(',char('e'+f-1),')']);  % bottom row: (e)-(h)

   % ['/beamformed_data_',tag{f},'_SOS_',num2str(channel_data.sound_speed)]
   % b_data_CC_postprocess.write(['./compare_transmit_types','_SOS_',num2str(channel_data.sound_speed),'.uff'],['/beamformed_data_',tag{f}]);

    b_data_compare.scan =  b_data_CC_postprocess.scan;
    b_data_compare.data(:,1,1,f) = b_data_CC_postprocess.data./max(b_data_CC_postprocess.data);
end
%%
%b_data_compare.data(:,1,1,2) = [];

fig = figure();
b_data_compare.plot(fig,['1=FI,2=DW,3=PW,4=STA']);
b_data_compare.save_as_gif('no_compensation.gif');

function save_fig5_panel(fig, ax, filepath, show_xlabel, show_ylabel, panel_label)
%SAVE_FIG5_PANEL Export a tight Fig. 5 panel without title or colorbar.
%
% A white bold panel label (e.g. '(a)') is burned into the top-left corner of
% the image itself, so it stays on the image regardless of the LaTeX layout.
% All panels use the same normalized axes position so the image areas align in
% LaTeX without trimming.

    title(ax, '');

    if show_xlabel
        xlabel(ax, 'x [mm]');
    else
        xlabel(ax, '');
        ax.XTickLabel = {};
    end

    if show_ylabel
        ylabel(ax, 'z [mm]');
    else
        ylabel(ax, '');
        ax.YTickLabel = {};
    end

    axis(ax, 'image');
    colormap(ax, 'gray');
    ax.Units = 'normalized';
    ax.Position = [0.14 0.12 0.72 0.84];  % leave room for colorbar

    colorbar(ax);

    if nargin >= 6 && ~isempty(panel_label)
        text(ax, 0.03, 0.955, panel_label, 'Units', 'normalized', ...
            'Color', 'w', 'FontWeight', 'bold', 'FontSize', 14, ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');
    end

    set(fig, 'PaperPositionMode', 'auto');
    set(fig, 'InvertHardcopy', 'off');
    saveas(fig, filepath, 'eps2c');
end