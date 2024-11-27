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

// The processFile reads in the confocal image files and counts foci within identifiable nuclei
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
			// For all other probes, use a lower maximum tolerance to find foci
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
	   // Choose the color channel with the probe (usually C1)
	   selectImage("C1-"+imname);
	   // Increase contrast in the probe image
	   run("Enhance Contrast...", "saturated=0.001");
	   // Convert to RGB color
	   run("RGB Color");
	   // Save a copy of the probe image as a tif file
	   saveAs("Tiff", save_dir+"/"+savename+"_Probe.tif");
	   // Get the name of the probe figure to use it for other image operations below
	   probefig = getTitle();
	   // Choose the color channel with the DAPI nuclear counterstain (usually C2)
	   selectImage("C2-"+imname);
	   // Convert to RGB color
	   run("RGB Color");
	   // Save a copy of the DAPI image as a tif file
	   saveAs("Tiff", save_dir+"/"+savename+"_DAPI.tif");
	   // Get the name of the DAPI figure to use it for other image operations below
	   dapifig = getTitle();
	   // Merge the probe and DAPI images into a single image
	   run("Merge Channels...", "c1="+savename+"_Probe.tif c3="+savename+"_DAPI.tif create keep");
	   selectImage("Composite");
	   // Convert to RGB color
	   run("RGB Color");
	   // Save a copy of the composite image as a tif file
	   saveAs("Tiff", save_dir+"/"+savename+"_Composite.tif");

	   //
	   // Find nuclei
	   //
	   
	   selectImage(dapifig);
	   // Use the average pixel intensity of the DAPI image to determine whether any nuclei were detected (an empty image with noise has a higher average)
	   if (getValue("Mean")<20) {
		   // Blur the DAPI image using a Gaussian with sigma of 10
		   run("Gaussian Blur...", "sigma=10");
		   // Convert the image to an 8 bit image
		   run("8-bit");
		   // Threshold the image
		   setAutoThreshold("Default dark no-reset");
		   setOption("BlackBackground", true);
		   // Create a binary mask for the nuclei
		   run("Convert to Mask");
		   // Fill in small holes in the mask
		   run("Fill Holes");
		   // Use the watershed algorithm to split adjacent nuclei
		   run("Watershed");
		   // Identify individual nuclei and add an overlay to number them
		   run("Analyze Particles...", "size=50-1000 show=[Overlay Masks] add");
		   // Save the nuclear mask overlay
		   saveAs("Jpeg", save_dir+"/"+savename+"_mask.jpg");

		   //
		   // Identify foci
		   //

		   // Check if any nuclei were detected before running analysis
		   if (roiManager("Count")>0) {
			   // For the first image, set the number of results to 0
			   if (n==1) {
					numres = 0;
				}
				// Otherwise, set the number of results to how many foci are already in the Results table
				else {
					numres = nResults;
				}
			   
			   selectImage(probefig);
			   // Convert the probe image to 8 bit
			   run("8-bit");
			   // Find some values from the probe image
			   getStatistics(area, mean, min, max, std);
			   // Smooth the image with a Gaussian to reduce noise
			   run("Gaussian Blur...", "sigma=5");
			   // Use the predefined tolerance to identify foci using local maxima detection
			   run("Find Maxima...", "prominence="+maxTol+" output=[Single Points]");
			   // Deselect ROIs to measure foci in all of the identified nuclei within the image
			   roiManager("Deselect");
			   roiManager("Measure");
			   // Loop through each nucleus in the image (each row corresponds to a single nucleus)
			   for (row=numres; row<nResults; row++) {
					// The number of foci is the number of pixels within the mask (RawIntDen) divided by the total number of pixels in an image
					val = getResult("RawIntDen", row)/getResult("Max", row);
					// Place the number of foci in the results table
					setResult("NumFoci", row, val);
					// Annotate the row with the name of the treatment or sample
					setResult("Sample", row, sampname);
					// Annotate the row with the cell number identifier
					setResult("Cell", row, savename);
					// Check the standard deviation of pixel intensities in the image (low value means it is mostly noise with no fluorescence)
					if (std>1) {
						setResult("BlankImage", row, "No");
					}
					else {
						setResult("BlankImage", row, "Yes");
					}
				}
				
			   // Update the results table with the changes made in the for loop
			   updateResults();
			   // Clear the identified nuclear ROIs from the ROI Manager
			   roiManager("Delete");
			   // Close the open images
			   close(savename+"_DAPI.tif");
			   close(savename+"_Probe.tif");
			   

			   //
			   // Save processed images
			   //
			   

			   // Open the DAPI image and the probe image
			   open(save_dir+"/"+savename+"_DAPI.tif");
			   run("8-bit");
			   open(save_dir+"/"+savename+"_Probe.tif");
			   run("8-bit");
			   // Use the predefined tolerance to identify foci using local maxima detection and return a mask image for all pixels in the maxima
			   run("Find Maxima...", "prominence="+maxTol+" output=[Maxima Within Tolerance]");
			   // Use the mask on the probe image to get the actual pixel values within the maxima
			   imageCalculator("AND create",savename+"_Probe.tif Maxima-1",savename+"_Probe.tif");
			   // Overlay the DAPI nucleus image with the masked probe image
			   run("Merge Channels...", "c3="+savename+"_DAPI.tif"+" c6=[Result of "+savename+"_Probe.tif Maxima-1"+"] create");
			   // Convert the image to RGB color
			   run("RGB Color");
			   // Adjust contrast within the image
			   setMinAndMax(0, 100);
			   // Save the final image
			   saveAs("Tiff", save_dir+"/"+savename+"_Foci.tif");
			}
		}
		// Close all open images
	   run("Close All");
	}
}