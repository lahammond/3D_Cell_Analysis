// CIZI 3D Cell Counter
//
// Author: 	Luke Hammond
// Cellular Imaging | Zuckerman Institute, Columbia University
// Version: 0.1
// Date:	4th April 2018
//
// For detection of cells in 3D images. Generates a CSV file containing total counts and image #
// Expects multichannel TIF from 3D Brain Region Enhancement


// Initialization
requires("1.51w");
starttime = getTime();
run("Options...", "iterations=3 count=1 black do=Nothing");
run("Set Measurements...", "fit redirect=None decimal=3");
run("Colors...", "foreground=white background=black selection=yellow");
run("Clear Results");

// menu
Dialog.create("CIZI 3D Cell Counter");
Dialog.addNumber("Resolution used for detecting cells (um/px) (0 for original resolution)", 0);
Dialog.addMessage("---");
Dialog.addNumber("Select channel containing cells:", 1);
Dialog.addNumber("Unsharp Mask radius (px, 0 if none):", 25);
Dialog.addNumber("Unsharp Mask weight:", 0.7);
Dialog.addNumber("OSBS Filter radius (px):", 5);
Dialog.addNumber("OSBS Filter iterations:", 20);
Dialog.addNumber("Minimum cell volume used for cell detection (um):", 150);

Dialog.addMessage("---");
Dialog.addNumber("Select additional channel containing cells (0 if none):", 0);
Dialog.addNumber("Unsharp Mask radius (px, 0 if none):", 25);
Dialog.addNumber("Unsharp Mask weight:", 0.7);
Dialog.addNumber("OSBS Filter radius (px):", 5);
Dialog.addNumber("OSBS Filter iterations:", 20);
Dialog.addNumber("Minimum cell volume used for cell detection (um):", 150);

Dialog.addCheckbox("Save object validation images?",true);
Dialog.addCheckbox("Save post-filter images (for troubleshooting)?",false);

Dialog.show();

// Dialog Outputs
FinalRes = Dialog.getNumber();
//
CellCh = Dialog.getNumber();
USSZ = Dialog.getNumber();
USMW = Dialog.getNumber();
OSBSRad = Dialog.getNumber();
OSBSItr = Dialog.getNumber();
MinSz = Dialog.getNumber();
//
CellCh2 = Dialog.getNumber();
USSZ2 = Dialog.getNumber();
USMW2 = Dialog.getNumber();
OSBSRad2 = Dialog.getNumber();
OSBSItr2 = Dialog.getNumber();
MinSz2 = Dialog.getNumber();

savevalidationimages = Dialog.getCheckbox();
savepostfilter = Dialog.getCheckbox();


// Other values

RORad = 4;
RORad2 = 4;



// Preparation
input = getDirectory("Input directory:");
print("\\Clear");
print("3D Cell Counter running:");
setBatchMode(true);

// Create folders
File.mkdir(input + "Analyzed");
File.mkdir(input + "Analyzed/Channel"+CellCh+"_Object_Validation");
ChOut = input + "Analyzed/Channel"+CellCh+"_Object_Validation/";

if (CellCh2 > 0) {
	File.mkdir(input + "Analyzed/Channel"+CellCh2+"_Object_Validation");
	Ch2Out = input + "Analyzed/Channel"+CellCh2+"_Object_Validation/";
}

//Create Table - either have open the whole time or open and close after each iteration
TableTitle = "Cell_Counts"; 
TableTitle = "["+TableTitle+"]"; 
f=TableTitle;  
run("New... ", "name="+TableTitle+" type=Table"); 
//CellCh2=2;
//CellCh=1;
if (CellCh2 > 0) {
	print(f,"\\Headings:Image\tCountCh"+CellCh+"\tCountCh"+CellCh2);
} else {
	print(f,"\\Headings:Image\tCountCh"+CellCh);
}


// get files
files = getFileList(input);	
files = ImageFilesOnlyArray(files);		

run("Collect Garbage");

//iterate over all files

for(i=0; i<files.length; i++) {				
	image = files[i];	
	print("\\Update1: Processing image " + (i+1) +" of " + files.length +".");
	run("Bio-Formats Importer", "open=[" + input + image + "] autoscale color_mode=Default view=Hyperstack stack_order=XYCZT");
	getPixelSize(unit, W, H);
	getDimensions(width, height, ChNum, slices, frames);
	
	
	//Rescale Image 
	if (FinalRes > 0) {
		RescaleImage();
	} 

	

	rename("Raw");

	// Process First Cell Channel

	// multichannel?
	if (ChNum > 1) {
		run("Split Channels");
		selectWindow("C" + CellCh + "-Raw");
	}
	rename("Ch1");
	
	run("Duplicate...", "title=Ch1-Raw duplicate");

	selectWindow("Ch1");
	//Process Image
	run("Unsharp Mask...", "radius="+USSZ+" mask="+USMW+" stack");
	run("Unsharp Mask...", "radius="+USSZ+" mask="+USMW+" stack");
	OSBSFilter("Ch1", OSBSRad, OSBSItr);
	
	
	run("Remove Outliers...", "radius="+RORad+" threshold=0 which=Bright stack");
	run("Remove Outliers...", "radius=4 threshold=10 which=Dark stack");

	if (savepostfilter == true) {
		saveAs("Tiff", ChOut + "OSBS_"+ image);
		rename("Ch1");
	}

	//Seed based object creation and cleanup
	
	run("3D Maxima Finder", "radiusxy=5 radiusz=5 noise=25");
	run("3D Watershed", "seeds_threshold=10 image_threshold=10 image=Ch1 seeds=peaks radius=5");
	closewindow("Ch1");
	closewindow("peaks");
	selectWindow("watershed");
	rename("Ch1");
		//binary mask
	setAutoThreshold("Default dark stack");
	setThreshold(1, 65535);
	run("Convert to Mask", "method=Default background=Dark black");
		//clean
	run("Remove Outliers...", "radius=4 threshold=50 which=Bright stack");

	
	//Run 3D analysis
	run("3D OC Options", "  dots_size=5 font_size=10 show_numbers white_numbers redirect_to=none");
	run("3D Objects Counter", "threshold=200 slice=12 min.="+MinSz+" max.=94672900 objects statistics");

	//Count results
	selectWindow("Results"); 
	C1Count = nResults;
	//Don't close results as it breaks the analysis!
	//closewindow("Results");

	if (savevalidationimages == true) {
		//Merge and colour
		selectWindow("Objects map of Ch1");
		run("16-bit");
		run("Merge Channels...", "c1=Ch1-Raw c2=[Objects map of Ch1] create");
		Stack.setChannel(1);
		run("Enhance Contrast", "saturated=0.1");
		run("Grays");
		Stack.setChannel(2);
		run("glasbey on dark");
		setMinAndMax(0, C1Count);
			
		
		// Save Validation Image
		//saveAs("Tiff", input +"Channel"+CellCh+"_Object_Validation/"+ image +"_objects.tif");
		
		saveAs("Tiff", ChOut + "objects_"+ image);
		closewindow("objects_"+ image);	
	} else {
		closewindow("Objects map of Ch1");
		closewindow("Ch1-Raw");
	}
	
	closewindow("Ch1");
	closewindow("Ch1");
	


	if (CellCh2 > 0) {
		selectWindow("C" + CellCh2 + "-Raw");
		rename("Ch2");
		
		run("Duplicate...", "title=Ch2-Raw duplicate");
		selectWindow("Ch2");
		//Process Image
		run("Unsharp Mask...", "radius="+USSZ2+" mask="+USMW2+" stack");
		run("Unsharp Mask...", "radius="+USSZ2+" mask="+USMW2+" stack");
		OSBSFilter("Ch2", OSBSRad2, OSBSItr2);
		
		run("Remove Outliers...", "radius="+RORad2+" threshold=0 which=Bright stack");
		run("Remove Outliers...", "radius=4 threshold=10 which=Dark stack");

		if (savepostfilter == true) {
			saveAs("Tiff", Ch2Out + "OSBS_"+ image);
			rename("Ch2");
		}
		
		
		//Seed based object creation and cleanup
	
		run("3D Maxima Finder", "radiusxy=5 radiusz=5 noise=25");
		run("3D Watershed", "seeds_threshold=10 image_threshold=10 image=Ch2 seeds=peaks radius=5");
		closewindow("Ch2");
		closewindow("peaks");
		selectWindow("watershed");
		rename("Ch2");
			//binary mask
		setAutoThreshold("Default dark stack");
		setThreshold(1, 65535);
		run("Convert to Mask", "method=Default background=Dark black");
			//clean
		run("Remove Outliers...", "radius=4 threshold=50 which=Bright stack");
		
		
		//Run 3D analysis
		run("3D OC Options", "  dots_size=5 font_size=10 show_numbers white_numbers redirect_to=none");
		run("3D Objects Counter", "threshold=200 slice=12 min.="+MinSz+" max.=94672900 objects statistics");

		//Count results
		selectWindow("Results"); 
		C2Count = nResults;
		//closewindow("Results");
		
		
		// Save Validation Image
		//saveAs("Tiff", input +"Channel"+CellCh2+"_Object_Validation/"+ image +"_objects.tif");
		if (savevalidationimages == true) {
				//Merge and colour
			selectWindow("Objects map of Ch2");
			run("16-bit");
			run("Merge Channels...", "c1=Ch2-Raw c2=[Objects map of Ch2] create");
			Stack.setChannel(1);
			run("Enhance Contrast", "saturated=0.1");
			run("Grays");
			Stack.setChannel(2);
			run("glasbey on dark");
			setMinAndMax(0, C2Count);	

			saveAs("Tiff", Ch2Out + "objects_"+ image);
			closewindow("objects_"+ image);
		} else {
			closewindow("Objects map of Ch2");
			closewindow("Ch2-Raw");
		}
		closewindow("Ch2");
		closewindow("Ch2");
		

		
	}

	// Enter results into the results table
	
	if (CellCh2 > 0) {
		print(f, image+"\t"+C1Count+"\t"+C2Count); 
	} else {
		print(f, image+"\t"+C1Count); 
	}


run("Collect Garbage");

}


selectWindow("Cell_Counts");
saveAs("Results", input + "Cell_Counts.csv");
closewindow("Results");
closewindow("Cell_Counts");


endtime = getTime();
dif = (endtime-starttime)/1000;
print("\\Update5:Cell counts completed. Processing time =", (dif/60), "minutes. ", (dif/i), "seconds per image.");
print("\\Update6:----------------------------------------------------------------");
selectWindow("Log");
saveAs("txt", input+"Cell_Count_Log.txt");


/*
run("Remove Outliers...", "radius=2 threshold=0 which=Bright stack");
run("Unsharp Mask...", "radius=4 mask=0.70 stack");
run("Enhance Contrast...", "saturated=0.3 process_all use");
run("Remove Outliers...", "radius=4 threshold=0 which=Bright stack");
*/







function OSBSFilter(imagename, radius, iterations) {
	selectWindow(imagename);
	getDimensions(w2, h2, c2, slices, f2);
	rename("ROFimage");
	run("Duplicate...", "title=bgstack duplicate");
	run("Z Project...", "projection=[Max Intensity]");
	for(k=0; k<iterations; k++) {	
		run("Remove Outliers...", "radius="+radius+" threshold=0 which=Bright");
		//run("Morphological Filters", "operation=Dilation element=Disk radius=3");
	}
	run("Morphological Filters", "operation=Dilation element=Disk radius=10");
	rename("morph");
	selectWindow("MAX_bgstack");
	close();
	selectWindow("morph");
	rename("MAX_bgstack");
	
	for (m=0; m<slices; m++) {
		selectWindow("MAX_bgstack");
		run("Select All");
		run("Copy");
		selectWindow("bgstack");
		setSlice(m+1);
		run("Paste");
	}
	selectWindow("MAX_bgstack");
	close();
	
	imageCalculator("Subtract create stack", "ROFimage","bgstack");
	selectWindow("bgstack");
	close();
	selectWindow("ROFimage");
	close();
	selectWindow("Result of ROFimage");
	rename(imagename);
}	

function ImageFilesOnlyArray (arr) {
	//pass array from getFileList through this e.g. NEWARRAY = ImageFilesOnlyArray(NEWARRAY);
	setOption("ExpandableArrays", true);
	f=0;
	files = newArray;
	for (i = 0; i < arr.length; i++) {
		if(endsWith(arr[i], ".tif") || endsWith(arr[i], ".nd2") ) {   //if it's a tiff image add it to the new array
			files[f] = arr[i];
			f = f+1;
		}
	}
	arr = files;
	Array.sort(arr);
	return arr;
}

function DeleteDir(Dir){
	listDir = getFileList(Dir);
  	//for (j=0; j<listDir.length; j++)
      //print(listDir[j]+": "+File.length(myDir+list[i])+"  "+File. dateLastModified(myDir+list[i]));
 // Delete the files and the directory
	for (j=0; j<listDir.length; j++)
		ok = File.delete(Dir+listDir[j]);
	ok = File.delete(Dir);
	if (File.exists(Dir))
	    print("\\Update10: Unable to delete temporary directory"+ Dir +".");
	else
	    print("\\Update10: Temporary directory "+ Dir +" and files successfully deleted.");
}

function RescaleImage(){
	//Expects FinalRes as an input from user in menu
	input_Title = getTitle();
	input_ID = getImageID();
	//get image information		
	getPixelSize(unit, W, H);
	// Determine rescale value
	Rescale = (1/(FinalRes/W));
	run("Scale...", "x="+Rescale+" y="+Rescale+" interpolation=Bilinear average create");
	rescale_ID = getImageID(); 
	selectImage(input_ID);
	close();
	selectImage(rescale_ID);
	rename(input_Title);
}

function NumberedArray(maxnum) {
	//use to create a numbered array from 1 to maxnum, returns numarr
	//e.g. ChArray = NumberedArray(ChNum);
	numarr = newArray(maxnum);
	for (i=0; i<numarr.length; i++){
		numarr[i] = (i+1);
	}
	return numarr;
}

function closewindow(windowname) {
	if (isOpen(windowname)) { 
      		 selectWindow(windowname); 
       		run("Close"); 
  		} 
}