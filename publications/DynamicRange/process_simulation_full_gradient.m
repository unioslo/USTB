clear all; close all;

filename = 'FieldII_STAI_gradient_full_field_100.uff';

channel_data = uff.channel_data();
channel_data.read([data_path,filesep,filename],'/channel_data');
%% Scan
scan=uff.linear_scan('x_axis',linspace(-20e-3,20e-3,256).', 'z_axis', linspace(5e-3,50e-3,2048).');

%% Beamformer

mid = midprocess.das();
mid.channel_data=channel_data;
mid.scan=scan;
mid.dimension = dimension.transmit();
mid.receive_apodization.window=uff.window.boxcar;
mid.receive_apodization.f_number=1.75;
mid.transmit_apodization.window=uff.window.boxcar;
mid.transmit_apodization.f_number=1.75;
b_data_tx = mid.go();

%% Calculate weights to get uniform FOV. See example
[weights,array_gain_compensation,geo_spreading_compensation] = tools.uniform_fov_weighting(mid);

%% DELAY AND SUM
das=postprocess.coherent_compounding();
das.input = b_data_tx;
b_data_das = das.go();
b_data_das.data = b_data_das.data.*weights(:); %Compensate for geometrical spreading
b_data_das.plot([],'DAS');

%% COHERENCE FACTOR
cf = postprocess.coherence_factor();
cf.dimension = dimension.receive;
cf.receive_apodization = mid.receive_apodization;
cf.transmit_apodization = mid.transmit_apodization;
cf.input = b_data_tx;
b_data_cf = cf.go();
b_data_cf.data = b_data_cf.data.*weights(:);
b_data_cf.plot();

%% PHASE COHERENCE FACTOR
pcf = postprocess.phase_coherence_factor();
pcf.dimension = dimension.receive;
pcf.receive_apodization = mid.receive_apodization;
pcf.transmit_apodization = mid.transmit_apodization;
pcf.input = b_data_tx;
b_data_pcf = pcf.go();
b_data_pcf.data = b_data_pcf.data.*weights(:);
b_data_pcf.plot();

%% GENERALIZED COHERENCE FACTOR
gcf=postprocess.generalized_coherence_factor_OMHR();
gcf.dimension = dimension.receive;
gcf.transmit_apodization = mid.transmit_apodization;
gcf.receive_apodization = mid.receive_apodization;
gcf.input = b_data_tx;
gcf.channel_data = channel_data;
gcf.M0 = 2;
b_data_gcf = gcf.go();

b_data_gcf.data = b_data_gcf.data.*weights(:);
b_data_gcf.plot();

%% MINIMUM VARIANCE
mv = postprocess.capon_minimum_variance();
mv.dimension = dimension.receive;
mv.transmit_apodization = mid.transmit_apodization;
mv.receive_apodization = mid.receive_apodization;
mv.input = b_data_tx;
mv.scan = scan;
mv.channel_data = channel_data;
mv.K_in_lambda = 1.5;
mv.L_elements = channel_data.probe.N/2;
mv.regCoef = 1/100;
b_data_mv = mv.go();
b_data_mv.data = b_data_mv.data.*weights(:);
b_data_mv.plot();

%% EIGENSPACE BASED MINIMUM VARIANCE
ebmv=postprocess.eigenspace_based_minimum_variance();
ebmv.dimension = dimension.receive;
ebmv.input = b_data_tx;
ebmv.channel_data = channel_data;
ebmv.scan = scan;
ebmv.K_in_lambda = 1.5;
ebmv.gamma = 0.5;
ebmv.L_elements = floor(channel_data.N_elements/2);
ebmv.transmit_apodization = mid.transmit_apodization;
ebmv.receive_apodization = mid.receive_apodization;
ebmv.regCoef = 1/100;

b_data_ebmv = ebmv.go();
b_data_ebmv.data = b_data_ebmv.data.*weights(:);
b_data_ebmv.plot();

%% F-DMAS
dmas=postprocess.delay_multiply_and_sum();
dmas.dimension = dimension.receive;
dmas.transmit_apodization = mid.transmit_apodization;
dmas.receive_apodization = mid.receive_apodization;
dmas.input = b_data_tx;
dmas.channel_data = channel_data;
b_data_dmas = dmas.go();
b_data_dmas.plot()

%% GLT
glt_s = postprocess.scurve_gray_level_transform();
glt_s.a = 0.12;
glt_s.b = -40;
glt_s.c = 0.008;
glt_s.plot_functions = 1;
glt_s.input = b_data_das;
glt_s.scan = b_data_das.scan;
b_data_glt = glt_s.go();
b_data_glt.plot();

%%
addpath([ustb_path,'/publications/DynamicRage/functions']);
image.all{1} = b_data_das.get_image;
image.tags{1} = 'DAS';
image.all{2} = b_data_mv.get_image;
image.tags{2} = 'MV';
image.all{3} = b_data_ebmv.get_image;
image.tags{3} = 'EBMV';
image.all{4} = b_data_dmas.get_image;
image.tags{4} = 'F-DMAS';
image.all{5} = b_data_cf.get_image;
image.tags{5} = 'CF';
image.all{6} = b_data_gcf.get_image;
image.tags{6} = 'GCF';
image.all{7} = b_data_pcf.get_image;
image.tags{7} = 'PCF';
image.all{8} = b_data_glt.get_image;
image.tags{8} = 'GLT';

colors=    [0.9047    0.1918    0.1988; ...
            0.2941    0.5447    0.7494; ...
            0.3718    0.7176    0.3612; ...
            1.0000    0.5482    0.1000; ...
            0.8650    0.8110    0.4330; ...
            0.6859    0.4035    0.2412; ...
            0.9718    0.5553    0.7741; ...
            0.6400    0.6400    0.6400];

x_axis_grad_start = 14;
mask_lateral=abs(b_data_das.scan.x_axis)<x_axis_grad_start*10^-3;
theory_lateral = (-1.8*(b_data_das.scan.x_axis(mask_lateral)+x_axis_grad_start*10^-3))*10^3;

[meanLines,~] = getMeanLateralLines(b_data_das,image,5,50,-x_axis_grad_start,x_axis_grad_start);

f10 = figure(77);clf;hold all;
plot(theory_lateral,theory_lateral,'k--','DisplayName','Theory','linewidth',2); hold on; grid on;
for i = 1:length(image.all)
    plot(theory_lateral,meanLines.all{i}-max(meanLines.all{i}),'linewidth',2,'DisplayName',image.tags{i},'Color',colors(i,:));
end
xlabel('Theoretical [dB]');
ylabel('Output [dB]');
set(gca, 'XDir','reverse');
title('Average response of the gradient');
xlim([-50 0])
ylim([-80 0])
legend('Location','sw');
