// ThresholdMacro.ijm

// ask the user for the directory with images to process
dir = getDirectory("Choose directory");
list = getFileList(dir);

// note start time, for benchmarking
start = getTime();

// we only process files ending in .czi
czilist = newArray(0);
for(w = 0; w < list.length; w++) {
	if(endsWith(list[w], 'czi')) {
		czilist = Array.concat(czilist, list[w]);
	}
}

// loop over all images
for(w = 0; w < czilist.length; w++) {
	name = dir + File.separator + czilist[w];
	basename = czilist[w];

	run("Bio-Formats Windowless Importer", "open=" + name);

	// get creation date from image metadata
	create = getMetadata("Information|Document|CreationDate #1");
	spl = split(create);

	crdate = '';
	for(i = 0; i < lengthOf(spl); i++){
		if (spl[i] == "Information|Document|CreationDate") {
			crdate = spl[i+3];
		}
	}

	// save the gfp channel and close the others
	run("Split Channels");
	close("C3-*");
	close("C2-*");
	saveAs("Tiff", name + ".gfp.tif");

	run("8-bit");
	setAutoThreshold("Percentile");

	// thresholding magic
	setThreshold(0, 1);
	run("Convert to Mask");
	run("Make Binary");
	run("Options...", "iterations=3 count=7 pad do=Open");
	run("Remove Outliers...", "radius=10 threshold=50 which=Bright");
	run("Invert");
	run("Options...", "iterations=3 count=4 pad do=Dilate");
	run("Fill Holes");
	run("Erode");
	run("Analyze Particles...", "size=500-5000 show=Masks clear add");

	run("ROI Manager...");
	nrois = roiManager("count");

	// process the rois, if there are any
	if (nrois > 0) {
		selectWindow("Mask of " + basename + ".gfp.tif");
		saveAs("Tiff", name + ".mask.tif");

		run("Bio-Formats Windowless Importer", "open=" + name);

		for (i = 0; i < nrois; i++) {
			roiManager("Select", i);
			roiManager("Multi-measure measure_all append one");
		}

		// save the results to .csv file
		run("Input/Output...", "jpeg=0 gif=-1 file=.csv use_file copy_column copy_row save_column save_row");
		saveAs("Results", name + ".csv");

		// this is an ugly hack but it works ok for importing into R
		File.append(",,,,,," + crdate, name + ".csv");
	}

	if (nrois>0) {
		roiManager("reset");
	}

	// clean up before the next iteration
	run("Clear Results");
	while (nImages>0) { 
		selectImage(nImages);
		close();
	}
}

if (isOpen("ROI Manager")) {
	selectWindow("ROI Manager");
	run("Close");
}

if (isOpen("Results")) {
	selectWindow("Results");
	run("Close");
}

elapsed = (getTime() - start) / 1000;
num = czilist.length;
print("Processed " + num + " images in " + elapsed + " seconds.");
