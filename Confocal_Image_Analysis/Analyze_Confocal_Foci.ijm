// "Analyze_Confocal_Foci.ijm"
// Jane Frederick
// Last updated 1-25-2024
// This macro recursively batch processes all confocal .nd2 files in a selected folder and outputs the number of foci detected within each identified nucleus.

//
// MAIN SCRIPT
//

// Close all open images, clear the ROI manager, and clear the Results table
run("Fresh Start");

// Ask user for folder with confocal images
dir = getDirectory("Choose a Directory ");

// Create a folder to save the analysis in the parent directory with the word "Compiled" appended to the folder name
savedir = File.getParent(dir)+"/Compiled_"+File.getNameWithoutExtension(dir);
// If the directory does not exist already, create the save directory to save analyzed images
if (!File.exists(savedir)){
	File.makeDirectory(savedir);
}

setBatchMode(true);

// Initialize a variable to count the number of files that can be analyzed
count = 0;
// Count the number of files that need to be processed
countFiles(dir);

// Update the measurements performed for nuclear ROIs
run("Set Measurements...", "area mean min integrated redirect=None decimal=3");

// Initialize a variable to count the number of images that have been analyzed
n = 0;
// Initialize a variable to count the number of total nuclei analyzed in the Results table
numres = 0;
// Run the image analysis
processFiles(dir,savedir);
// Save the data from the Results table into a CSV file in the save directory
saveAs("Results", savedir+"/Foci_Results.csv");

//
// FUNCTIONS
//

// The countFiles function loops through all subdirectories to find the number of analyzable files
function countFiles(dir) {
  // Get the list of files within the current directory
  list = getFileList(dir);
  // Loop through the list of files
  for (i=0; i<list.length; i++) {
      // Check if the current file is a folder
      if (endsWith(list[i], "/")) {
      	// If the current file is a folder, call the countFiles function again to run a recursive count
      	countFiles(""+dir+list[i]);
      }
      else {
      	// If the current file is not a folder, add to the analyzable file count
      	count++;
      }
  }
}

// The processFiles function loops through subdirectories and calls the processFile function when it finds an image
function processFiles(dir,save_dir) {
	// Get the list of files within the current directory
	list = getFileList(dir);
	// Save the file path for the input save directory so that subdirectories can be created
	savefold = save_dir;
	// Loop through the list of files
	for (i=0; i<list.length; i++) {
		// Check if the current file is a folder
		if (endsWith(list[i], "/")) {
			// Create a subfolder within the save directory if the current file is a folder
			newsavefold = savefold+"/"+list[i];
			// If the directory does not exist already, create the new subdirectory
			if (!File.exists(newsavefold)) {
				File.makeDirectory(newsavefold);
			}
			// Call the processFiles function again to run a recursive analysis
			processFiles(""+dir+list[i],newsavefold);
	  }
	  else {
	     // Update the analyzed figure variable and show how many files have been processed
	     showProgress(n++, count);
	     // Append the file name to the file path
	     path = dir+list[i];
	     // Run the processFile function to perform image analysis
	     processFile(path,savefold);
	  }
	}
}

// The processFile reads in the confocal image files and counts foci within indentifiable nuclei
function processFile(path,save_dir) {
   // Check if the file is a .nd2 file (file type output by the Nikon confocal microscopes)
   if (endsWith(path, ".nd2")) {
       // Split the file path into the file name, the parent file path, and the parent folder name
       savename = File.getNameWithoutExtension(path);
       samp = File.getParent(path);
       sampname = File.getNameWithoutExtension(samp);
       
       // Check if the file has "Green" in the name
       if (sampname.contains('Green')) {
       		// Cells with green probes have more background fluorescence, so we increase the maximum tolerance for identifying foci
       		maxTol = 50;
       	}
       	else {
       		// For all other probes, use a lowere maximum tolerance to find foci
       		maxTol = 20;
       	}
       	
       	//
       	// Pre-process the confocal image
       	//

       // Open the confocal .nd2 image
       run("Bio-Formats Windowless Importer", "open=["+path+"] autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
       // Combine the Z stack into one image containing the maximum pixel intensity
       run("Z Project...", "projection=[Max Intensity]");
       // Get the file name
       imname = getTitle();
       // Split the stacked image into the different color channels (one should have DAPI and the other will have the DNA FISH probe)
       run("Split Channels");
       //
       selectImage("C1-"+imname);
       run("Enhance Contrast...", "saturated=0.001");
       run("RGB Color");
       saveAs("Tiff", save_dir+"/"+savename+"_Probe.tif");
       probefig = getTitle();
       //
       selectImage("C2-"+imname);
       run("RGB Color");
       saveAs("Tiff", save_dir+"/"+savename+"_DAPI.tif");
       dapifig = getTitle();
       //
       run("Merge Channels...", "c1="+savename+"_Probe.tif c3="+savename+"_DAPI.tif create keep");
       selectImage("Composite");
       run("RGB Color");
       saveAs("Tiff", save_dir+"/"+savename+"_Composite.tif");

       // Create nuclear mask based on DAPI image
       selectImage(dapifig);
       // Check if the DAPI image has clear fluorescence by making sure the histogram is centered at a lower value
       if (getValue("Mean")<20) {
	       //
	       // Find nuclei
	       //
	       
	       //
	       run("Gaussian Blur...", "sigma=10");
	       //
	       run("8-bit");
	       //
	       setAutoThreshold("Default dark no-reset");
	       setOption("BlackBackground", true);
	       //
	       run("Convert to Mask");
	       //
	       run("Fill Holes");
	       //
	       run("Watershed");
	       //
	       run("Analyze Particles...", "size=50-1000 show=[Overlay Masks] add");
	       //
	       saveAs("Jpeg", save_dir+"/"+savename+"_mask.jpg");
	
	       // Check if any nuclei were detected before running analysis
	       if (roiManager("Count")>0) {
		       //
		       // Identify foci
		       //
		       
		       //
		       if (n==1) {
		       		numres = 0;
		       	}
		       	else {
		       		numres = nResults;
		       	}
		       //
		       selectImage(probefig);
		       run("8-bit");
		       //
		       getStatistics(area, mean, min, max, std);
	       	   // Calculate the number of foci per nucleus
	       	   run("Gaussian Blur...", "sigma=5");
	       	   //
		       run("Find Maxima...", "prominence="+maxTol+" output=[Single Points]");
		       //
		       roiManager("Deselect");
		       roiManager("Measure");
		       //
		       for (row=numres; row<nResults; row++) {
			       	//
			       	val = getResult("RawIntDen", row)/getResult("Max", row);
			       	//
			       	setResult("NumFoci", row, val);
			       	//
			       	setResult("Sample", row, sampname);
			       	//
			       	setResult("Cell", row, savename);
			       	//
			       	if (std>1) {
			       		setResult("BlankImage", row, "No");
			       	}
			       	else {
			       		setResult("BlankImage", row, "Yes");
			       	}
			    }
			    //
			    updateResults();
			   // Clear the identified nuclear ROIs from the ROI Manager
		       roiManager("Delete");
		       // Close the open images
		       close(savename+"_DAPI.tif");
		       close(savename+"_Probe.tif");
		       
		       //
		       // Save processed images
		       //
		       
		       // Create new image with foci labeled
		       open(save_dir+"/"+savename+"_DAPI.tif");
		       run("8-bit");
		       open(save_dir+"/"+savename+"_Probe.tif");
		       run("8-bit");
		       //
		       run("Find Maxima...", "prominence="+maxTol+" output=[Maxima Within Tolerance]");
		       //
		       imageCalculator("AND create",savename+"_Probe.tif Maxima-1",savename+"_Probe.tif");
		       //
		       run("Merge Channels...", "c3="+savename+"_DAPI.tif"+" c6=[Result of "+savename+"_Probe.tif Maxima-1"+"] create");
		       //
		       run("RGB Color");
		       setMinAndMax(0, 100);
		       saveAs("Tiff", save_dir+"/"+savename+"_Foci.tif");
			}
       	}
       	// Close all open images
       run("Close All");
  	}
}