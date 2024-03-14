% Crowding volume fraction
phi = 0.37; % A549 CVC value from Li et al. 2022
% Genomic size of a packing domain in base pairs (bp)
Nf = 207e3; % A549 N_f value from Li et al. 2022
% Cell thickness in um
thickness = 2;

% Refractive index of the substance the cell is submerged in
RI = 1.337; % RI of cell culture media
% Illumination NA (determined by size of A stop)
NAi = 0.52; % Measured using NA calculator or hexagon size
% Collection NA (written on objective)
NAc = 1.49; % NA of 100x objective
% Central imaging wavelength in nm
lambda = 585; 
% The type of objective used to image (change to false if using air
% objective)
oil_objective = true; % 60x, 63x, and 100x objectives are oil immersion
% The z location used when imaging (change to false if imaging was done
% above the glass surface)
cell_glass = true; % PWS images were taken where the cell contacts the dish

liveCellRI = S2D.RIDefinition.createFromGladstoneDale(RI, phi);
nuSys = S2D.SystemConfiguration(liveCellRI, NAi, NAc, lambda, oil_objective, cell_glass);

rms = linspace(0,0.497);
[dOut,dCorrected, Nf_expected,lmax_corrected] = SigmaToD_AllInputs(rms, nuSys, Nf, thickness);
convlut = [rms;dOut;dCorrected;Nf_expected;lmax_corrected];

conversion_table = array2table(convlut','VariableNames',{'RMS','Db','D','Nf','lmax'});
writetable(conversion_table,'SigmaToDLUT_LCPWS2.csv');