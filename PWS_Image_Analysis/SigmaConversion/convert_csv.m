clear all

phi = 0.35;
Nf = 5e5;
noiseRms = 0.007; % The RMS measurement in background regions where true RMS should be 0.
thickness = 2; % um

csvName = '\\backmanlabnas.myqnapcloud.com\Public\CRISPR-FISH Paper Experiments\FISH PWS\FISH PWS Results.csv';
outName = '\\backmanlabnas.myqnapcloud.com\Public\CRISPR-FISH Paper Experiments\FISH PWS\FISH PWS Results D.csv';

liveCellRI = S2D.RIDefinition.createFromGladstoneDale(1.337, phi);
nuSys = S2D.SystemConfiguration(liveCellRI, 0.52, 1.49, 585, true, true);

opts =detectImportOptions(csvName, 'VariableNamingRule', 'preserve');
myTable = readtable(csvName, opts);
rms = table2array(myTable(:, "RMS"));

rms = sqrt(rms.^2 - noiseRms^2);

[dOut,dCorrected, Nf_expected,lmax_corrected] = SigmaToD_AllInputs(rms, nuSys, Nf, thickness);

myTable = [myTable table(dCorrected, 'VariableNames', {'D'})];
writetable(myTable, outName);