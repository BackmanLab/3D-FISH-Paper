clear all

userfolder = 'C:\Users\janef';
paperfolder = '\OneDrive - Northwestern University\Documents - Backman Lab - Shared Folders\Lab Paper Drafts\FISH vs. CRISPR';
parentfolder = strcat(userfolder,paperfolder);

csvfolder = '\PLOS ONE Revision Files\PLOS ONE Revision Experiments\FISH PWS\1-30-2024\';
csvfile = "3D FISH PWS data.csv";
outfile = "3D FISH PWS data_D.csv";

csvName = strcat(parentfolder,csvfolder,csvfile);
outName = strcat(parentfolder,csvfolder,outfile);

% The RMS measurement in background regions where true RMS should be 0.
noiseRms = 0.007; 

% Add folder with functions to convert RMS to D to MATLAB path
functionpath = '\PLOS ONE Revision Files\Scripts\Sigma to D';
addpath(genpath(strcat(parentfolder,functionpath)));

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

opts = detectImportOptions(csvName, 'VariableNamingRule', 'preserve');
myTable = readtable(csvName, opts);
rms = table2array(myTable(:, "RMS"));

rms = sqrt(rms.^2 - noiseRms^2);

[dOut,dCorrected, Nf_expected,lmax_corrected] = SigmaToD_AllInputs(rms, nuSys, Nf, thickness);

myTable = [myTable table(dCorrected, 'VariableNames', {'D'})];
writetable(myTable, outName);