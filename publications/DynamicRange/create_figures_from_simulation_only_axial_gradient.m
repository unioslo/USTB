%clear all;
close all;

%filename = [data_path,filesep,'FieldII_STAI_dynamic_range_more_scatteres_old.uff'];
%filename = '/Users/omrindal/Development/USTB_dynamic_range/data/FieldII_STAI_dynamic_range_more_scatteres.uff';

%filename = '/Users/omrindal/Development/USTB_dynamic_range/data/FieldII_STAI_axial_gradient.uff';
filename = [data_path,filesep,'FieldII_STAI_axial_gradient_v2.uff'];

b_data_tx = uff.beamformed_data();
b_data_das = uff.beamformed_data();
b_data_cf = uff.beamformed_data();
b_data_pcf = uff.beamformed_data();
b_data_gcf = uff.beamformed_data();
b_data_mv = uff.beamformed_data();
b_data_ebmv = uff.beamformed_data();
b_data_dmas = uff.beamformed_data();
b_data_weights = uff.beamformed_data();

b_data_tx.read(filename,'/b_data_tx');
b_data_das.read(filename,'/b_data_das');
b_data_cf.read(filename,'/b_data_cf');
b_data_pcf.read(filename,'/b_data_pcf');
b_data_gcf.read(filename,'/b_data_gcf');
b_data_mv.read(filename,'/b_data_mv');
b_data_ebmv.read(filename,'/b_data_ebmv');
b_data_dmas.read(filename,'/b_data_dmas');
b_data_weights.read(filename,'/b_data_weights');
%%
weights = b_data_weights.get_image('none');
%%

das_img = b_data_das.get_image('none').*weights;  % Compensation weighting
das_img = db(abs(das_img./max(das_img(:))));                 % Normalize on max
f1 = figure(1);clf;
imagesc(b_data_das.scan.x_axis*1000,b_data_das.scan.z_axis*1000,das_img);
colormap gray;caxis([-60 0]);axis image;xlabel('x [mm]');ylabel('z [mm]');
set(gca,'FontSize',14)
saveas(f1,[ustb_path,filesep,'publications/DynamicRage/figures/simulation_axial_gradient_only/DAS'],'eps2c')

cf_img = b_data_cf.get_image('none').*weights;
cf_img = db(abs(cf_img./max(cf_img(:))));                 % Normalize on max

pcf_img = b_data_pcf.get_image('none').*weights;
pcf_img = db(abs(pcf_img./max(pcf_img(:))));

gcf_img = b_data_gcf.get_image('none').*weights;
gcf_img = db(abs(gcf_img./max(gcf_img(:))));


mv_img = b_data_mv.get_image('none').*weights;
mv_img = db(abs(mv_img./max(mv_img(:))));

dmas_img = b_data_dmas.get_image('none').*weights;
dmas_img = db(abs(dmas_img./max(dmas_img(:))));

ebmv_img = b_data_ebmv.get_image('none').*weights;
ebmv_img = db(abs(ebmv_img./max(ebmv_img(:))));


%%
addpath functions/

image.all{1} = das_img;
image.tags{1} = 'DAS';
image.all{2} = mv_img;
image.tags{2} = 'MV';
image.all{3} = ebmv_img;
image.tags{3} = 'EBMV';
image.all{4} = dmas_img;
image.tags{4} = 'F-DMAS';
image.all{5} = cf_img;
image.tags{5} = 'CF';
image.all{6} = gcf_img;
image.tags{6} = 'GCF';
image.all{7} = pcf_img;
image.tags{7} = 'PCF';



%%
colors=    [0.9047    0.1918    0.1988; ...
            0.2941    0.5447    0.7494; ...
            0.3718    0.7176    0.3612; ...
            1.0000    0.5482    0.1000; ...
            0.8650    0.8110    0.4330; ...
            0.6859    0.4035    0.2412; ...
            0.9718    0.5553    0.7741; ...
            0.6400    0.6400    0.6400];
        
gradient = -1.8;

[meanLines_axial,z_axis] = getMeanAxialLines(b_data_das,image,10,38,15,18.5);
mask_axial= b_data_das.scan.z_axis<38e-3 & b_data_das.scan.z_axis>10e-3;
theory_axial = (gradient*(b_data_das.scan.z_axis(mask_axial)-10e-3))*10^3;

f33 = figure(33);clf; hold all;
subplot(211);hold all;
plot(theory_axial,theory_axial,'LineStyle','-.','Linewidth',2,'DisplayName','Theoretical','Color',[0 0 0]);
plot(theory_axial,meanLines_axial.all{1}+abs(max(meanLines_axial.all{1})),'Linewidth',2,'DisplayName',image.tags{1},'Color',colors(1,:));
plot(theory_axial,meanLines_axial.all{2}-max(meanLines_axial.all{2}),'Linewidth',2,'DisplayName',image.tags{2},'Color',colors(2,:));
plot(theory_axial,meanLines_axial.all{3}-max(meanLines_axial.all{3}),'Linewidth',2,'DisplayName',image.tags{3},'Color',colors(3,:));
plot(theory_axial,meanLines_axial.all{4}-max(meanLines_axial.all{4}),'Linewidth',2,'DisplayName',image.tags{4},'Color',colors(4,:));
plot(theory_axial,meanLines_axial.all{5}-max(meanLines_axial.all{5}),'Linewidth',2,'DisplayName',image.tags{5},'Color',colors(5,:));
plot(theory_axial,meanLines_axial.all{6}-max(meanLines_axial.all{6}),'Linewidth',2,'DisplayName',image.tags{6},'Color',colors(6,:));
plot(theory_axial,meanLines_axial.all{7}-max(meanLines_axial.all{7}),'Linewidth',2,'DisplayName',image.tags{7},'Color',colors(7,:));
set(gca, 'XDir','reverse');
ylim([-100 0]);
xlim([-50 0])
%xlim([9 39]);
legend('Location','sw'); grid on;
ylabel('Normalized output [dB]');
xlabel('Input [dB]');
set(gca,'FontSize',12)

%%
saveas(f33,[ustb_path,filesep,'publications/DynamicRage/figures/simulation_axial_gradient_only/axial_gradient'],'eps2c')

%%