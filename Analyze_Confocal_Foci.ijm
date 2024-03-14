// "Analyze_FISH_Foci"
// Jane Frederick
// Last updated 12-6-2023
// This macro batch processes all .nd2 files in a folder and any subfolders.

run("Fresh Start");

// Ask user for folder with confocal images
dir = getDirectory("Choose a Directory ");
//run("Fix Funny Filenames", "which=["+dir+"]");
// Create a new directory to save analyzed images
savedir = File.getParent(dir)+"/Compiled_"+File.getNameWithoutExtension(dir);
if (!File.exists(savedir)){
	File.makeDirectory(savedir);
}

// Count the number of files that need to be processed
setBatchMode(true);
count = 0;
countFiles(dir);

// Run the image analysis
run("Set Measurements...", "area mean min integrated redirect=None decimal=3");
n = 0;
numres = 0;
processFiles(dir,savedir);
saveAs("Results", savedir+"/Foci_Results.csv");

// The countFiles function loops through all subdirectories to find the number of analyzable files
function countFiles(dir) {
  list = getFileList(dir);
  for (i=0; i<list.length; i++) {
      if (endsWith(list[i], "/")) {
      	countFiles(""+dir+list[i]);
      }
      else {
      	count++;
      }
  }
}

// The processFiles function loops through subdirectories and calls the processFile function when it finds an image
function processFiles(dir,save_dir) {
//	run("Fix Funny Filenames", "which=["+dir+"]");
	list = getFileList(dir);
	savefold = save_dir;
	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], "/")) {
			newsavefold = savefold+"/"+list[i];
			if (!File.exists(newsavefold)) {
				File.makeDirectory(newsavefold);
			}
			processFiles(""+dir+list[i],newsavefold);
	  }
	  else {
	     showProgress(n++, count);
	     path = dir+list[i];
	     processFile(path,savefold);
	  }
	}
}

//
function processFile(path,save_dir) {
   if (endsWith(path, ".nd2")) {
       savename = File.getNameWithoutExtension(path);
       samp = File.getParent(path);
       sampname = File.getNameWithoutExtension(samp);
       
       if (sampname.contains('Green')) {
       		maxTol = 50;
       	}
       	else {
       		maxTol = 20;
       	}

       // Open image and split channels into the probe and the nuclear counterstain
       run("Bio-Formats Windowless Importer", "open=["+path+"] autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
       run("Z Project...", "projection=[Max Intensity]");
       imname = getTitle();
       run("Split Channels");
       selectImage("C1-"+imname);
       run("Enhance Contrast...", "saturated=0.001");
       run("RGB Color");
       saveAs("Tiff", save_dir+"/"+savename+"_Probe.tif");
       probefig = getTitle();
       selectImage("C2-"+imname);
       run("RGB Color");
       saveAs("Tiff", save_dir+"/"+savename+"_DAPI.tif");
       dapifig = getTitle();
       run("Merge Channels...", "c1="+savename+"_Probe.tif c3="+savename+"_DAPI.tif create keep");
       selectImage("Composite");
       run("RGB Color");
       saveAs("Tiff", save_dir+"/"+savename+"_Composite.tif");

       // Create nuclear mask based on DAPI image
       selectImage(dapifig);
       // Check if the DAPI image has clear fluorescence by making sure the histogram is centered at a lower value
       if (getValue("Mean")<20) {
	       run("Gaussian Blur...", "sigma=10");
	       run("8-bit");
	       setAutoThreshold("Default dark no-reset");
	       setOption("BlackBackground", true);
	       run("Convert to Mask");
	       run("Fill Holes");
	       run("Watershed");
	       run("Analyze Particles...", "size=50-1000 show=[Overlay Masks] add");
	       saveAs("Jpeg", save_dir+"/"+savename+"_mask.jpg");
	
	       // Check if any nuclei were detected before running analysis
	       if (roiManager("Count")>0) {
		       if (n==1) {
		       		numres = 0;
		       	}
		       	else {
		       		numres = nResults;
		       	}
		       selectImage(probefig);
		       run("8-bit");
		       getStatistics(area, mean, min, max, std);
	       		// Calculate the number of foci per nucleus
	       		run("Gaussian Blur...", "sigma=5");
		       run("Find Maxima...", "prominence="+maxTol+" output=[Single Points]");
		       roiManager("Deselect");
		       roiManager("Measure");
		       for (row=numres; row<nResults; row++) {
			       	val = getResult("RawIntDen", row)/getResult("Max", row);
			       	setResult("NumFoci", row, val);
			       	setResult("Sample", row, sampname);
			       	setResult("Cell", row, savename);
			       	if (std>1) {
			       		setResult("BlankImage", row, "No");
			       	}
			       	else {
			       		setResult("BlankImage", row, "Yes");
			       	}
			    }
			    updateResults();
		       roiManager("Delete");
		       close(savename+"_DAPI.tif");
		       close(savename+"_Probe.tif");
		       
		       // Create new image with foci labeled
		       open(save_dir+"/"+savename+"_DAPI.tif");
		       run("8-bit");
		       open(save_dir+"/"+savename+"_Probe.tif");
		       run("8-bit");
		       run("Find Maxima...", "prominence="+maxTol+" output=[Maxima Within Tolerance]");
		       imageCalculator("AND create",savename+"_Probe.tif Maxima-1",savename+"_Probe.tif");
		       run("Merge Channels...", "c3="+savename+"_DAPI.tif"+" c6=[Result of "+savename+"_Probe.tif Maxima-1"+"] create");
		       run("RGB Color");
		       setMinAndMax(0, 100);
		       saveAs("Tiff", save_dir+"/"+savename+"_Foci.tif");
			}
       	}
       run("Close All");
  	}
}