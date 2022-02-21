// Brain Region Isolation and Analysis Tool

// Author: 	Luke Hammond
// Cellular Imaging | Zuckerman Institute, Columbia University
// Date:	13th April 2018
//	
// This macro allows for interactive isolation of a brain region. 

//	MIT License

//	Copyright (c) 2018 Luke Hammond lh2881@columbia.edu

//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the Software is
//	furnished to do so, subject to the following conditions:

//	The above copyright notice and this permission notice shall be included in all
//	copies or substantial portions of the Software.

//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//	SOFTWARE.

// Initialization
requires("1.41h");
starttime = getTime()
run("Options...", "iterations=1 count=1 edm=Overwrite");
//run("Set Measurements...", "fit redirect=None decimal=3");
run("Clear Results"); 
run("Close All");

// Options Window
Dialog.create("3D Brain Region Isolation and Enhancement Tool");

Dialog.addCheckbox("Extract region of interest from image?",false);
Dialog.addCheckbox("Apply attenuation correction?",true);
Dialog.addCheckbox("Extract substack?",false);
Dialog.addMessage("---");
Dialog.addCheckbox("Apply CLAHE (local contrast enhancement)?",false);
Dialog.addNumber("blocksize for CLAHE:", 25);
Dialog.addMessage("---");
Dialog.addCheckbox("Create depth-coded imaged for manual counting?",false);
Dialog.addString("Create depth-coded image for channed:", "3,4");

Dialog.show();


CropON = Dialog.getCheckbox();
AttenON = Dialog.getCheckbox();
SubStackON = Dialog.getCheckbox();
CLAHEON = Dialog.getCheckbox();
blocksize = Dialog.getNumber();
DepthCodeON = Dialog.getCheckbox();
DepthCodeChannels = Dialog.getString();

setBatchMode(true);

// Preparation
pathin = getDirectory("Input directory");
print("\\Clear");
print("3D Brain Region Isolation and Enhancement Tool");
print("Created by Luke Hammond, 2018. Contact: lh2881@columbia.edu");
print("Cellular Imaging | Zuckerman Institute, Columbia University - https://www.cellularimaging.org");


//setBatchMode(true);
files = getFileList(pathin);						// get an array containing the names of all files in the directory path
File.mkdir(pathin + "Enhanced");		// output directory

if (DepthCodeON == true) {
	File.mkdir(pathin + "Depth_coded_projections");
	DepthCodeChannelsIdx = num2array(DepthCodeChannels,",");
}




files = ImageFilesOnlyArray (files);


//iterate over all files
for(i=0; i<files.length; i++) {				


	// get the name of the current file
	image = files[i];							
	print("\\Update1: processing file " + (i+1) +"/" + files.length);
	// if the current file is a an image then: ALLOW BOTH ND2 AND TIF
	if (endsWith(image, ".nd2") || endsWith(image, ".tif") ) {		
		run("Bio-Formats Importer", "open=[" + pathin + image + "] autoscale color_mode=Composite view=Hyperstack stack_order=XYCZT");
		source_Title = getTitle();
		rename("source");
		source_ID = getImageID(); 
		Tif_Title = subtitle(source_Title);
				
		getPixelSize(unit, pW, pH);
		getDimensions(width, height, ChNum, slices, frames);

				
		//For Tif files saved from Elements - reoorder slices to channels
		//ND FILES MUST BE REORDERED - need rule for this so TIF are Fine - included at attenuation step
				
		ChArray = NumberedArray(ChNum);
		
		//enhance contrast for each channel for easier viewing		
		for(j=0; j<ChArray.length; j++) {
			Stack.setChannel(j+1);
			setSlice(parseInt((slices*ChNum)/2));
			run("Enhance Contrast", "saturated=0.35");
		}

		if (ChNum > 1) {
			run("Make Composite");
	
		}

		cleanupROI();
		setBatchMode(false);
		// Various options
		if (CropON == true && AttenON == false ) {
			setBatchMode("show");
			setTool("polygon");
			title = "WaitForUser";
			msg = "Create an ROI over the region of interest then click \"OK\".";
			waitForUser(title, msg);
			roiManager("Add");
			run("Select None");
			setBatchMode("hide");
			
		}

		if (CropON == true && AttenON == true ) {
			setBatchMode("show");
			setTool("polygon");
			title = "WaitForUser";
			msg = "Create an ROI over the region of interest and select slice for attentuation correction, then click \"OK\".";
			waitForUser(title, msg);
			roiManager("Add");
			run("Select None");
			//get slice
			Stack.setChannel(ChNum);
			AttenSlice= getSliceNumber();
			AttenSlice = AttenSlice/ChNum;
			setBatchMode("hide");
			
			
		}

		if (CropON == false && AttenON == true ) {
			title = "WaitForUser";
			msg = "Select slice for attentuation correction, then click \"OK\".";
			waitForUser(title, msg);
			//get slice
			Stack.setChannel(ChNum);
			AttenSlice= getSliceNumber();
			AttenSlice = AttenSlice/ChNum;
			
		}

		//setBatchMode(false);
		// SUBSTACK CAN BE HERE IF I DO MATH FOR ATTENUATION CORRECTION SHIFT!!

		if (SubStackON == true) {
			Dialog.create("Select top and bottom slices for substack:");
			Dialog.addNumber("Top slice:", 20);
			Dialog.addNumber("Bottom slice", 2);
			Dialog.show();
			TopSlice = Dialog.getNumber();
			BottomSlice = Dialog.getNumber();
			run("Make Substack...", "channels=1-"+ChNum+" slices="+BottomSlice+"-"+TopSlice);
			
			closewindow("source");
			if (ChNum == 1){
				selectWindow("Substack ("+BottomSlice+"-"+TopSlice+")");			
			} else {
				selectWindow("source-1");	
			}
			
			rename("source");
			
			AttenSlice = AttenSlice-(BottomSlice-1);
			getDimensions(width, height, ChNum, slices, frames);
			
		}
		//setBatchMode(false);
		if (ChNum > 1) {
			run("Split Channels");
	
		} else {
			rename("C1-source");
		}
		
		//ATTENUATION
		
		if (AttenON == true) {
			for(j=0; j<ChArray.length; j++) {
				selectWindow("C"+(j+1)+"-source");
				// ***Correction for ND2 slice frame weirdness
				//if (endsWith(image, ".nd2") != -1 && SubStackON == false) {	
				//	run("Re-order Hyperstack ...", "channels=[Slices (z)] slices=[Channels (c)] frames=[Frames (t)]");
				//}
							
				run("Attenuation Correction", "opening=3 reference="+(AttenSlice));
				closewindow("C"+(j+1)+"-source");
				closewindow("Background of C"+(j+1)+"-source");
				selectWindow("Correction of C"+(j+1)+"-source");
				rename("C"+(j+1)+"-source");
			}

		
		}

		// INDIVIDUAL CHANNEL PROCESSING
			// not included - part of automated analysis if required

		
		//Depth coded image generation
		if (DepthCodeON == true) {
			for(j=0; j<DepthCodeChannelsIdx.length; j++) {				
				selectWindow("C"+(DepthCodeChannelsIdx[j])+"-source");
				print(DepthCodeChannelsIdx[j]);
				run("Enhance Contrast", "saturated=0.0");
				getDimensions(width, height, dummy, dslices, frames);
				print(dslices);
				run("Temporal-Color Code", "lut=Spectrum start=1 end="+dslices);
				selectWindow("MAX_colored");
				
				saveAs("Tiff", pathin + "Depth_coded_projections/"+Tif_Title+"_"+DepthCodeChannelsIdx[j]);
				closewindow(Tif_Title+"_"+DepthCodeChannelsIdx[j]+".tif");
				selectWindow("C"+(DepthCodeChannelsIdx[j])+"-source");
				run("Enhance Contrast", "saturated=0.35");
			setBatchMode(true);
			}
		}

	

		//MERGE

		if (ChNum == 2) {
			run("Merge Channels...", "c1=C1-source c2=C2-source create");
		}

		if (ChNum == 3) {
			run("Merge Channels...", "c1=C1-source c2=C2-source c3=C3-source create");
		}

		if (ChNum == 4) {
			run("Merge Channels...", "c1=C1-source c2=C2-source c3=C3-source c4=C4-source create");
		}


		rename("source");


		
		//CROP LAST
		if (CropON == true){
			roiManager("Select", 0);
			run("Crop");
			run("Clear Outside", "stack");
			cleanupROI();
			run("Select None");
		}


		// Run CLAHE local contrast enhancement
		if (CLAHEON == true) {
			getDimensions(width, height, chs, sls, frames);	
			for (k=0; k<(sls*chs); k++) {
				setSlice(k+1);
				if (chs == 1) {
					run("Enhance Local Contrast (CLAHE)", "blocksize="+blocksize+" histogram=256 maximum=3 mask=*None* fast_(less_accurate)");
				} else {
					run("Enhance Local Contrast (CLAHE)", "blocksize="+blocksize+" histogram=256 maximum=3 mask=*None* fast_(less_accurate) process_as_composite");
				}
				//run("Enhance Local Contrast (CLAHE)", "blocksize=10 histogram=256 maximum=3 mask=*None* fast_(less_accurate)");
			}
		}



		//correct for ND2 weirdness here	
		getDimensions(width, height, dummy, newslices, frames);
		if (newslices > slices) {
			run("Deinterleave", "how="+ChNum);
			if (ChNum == 2) {
				run("Merge Channels...", "c1=[source #1] c2=[source #2] create");
				Stack.setChannel(1);
				run("Blue");
				Stack.setChannel(2);
				run("Green");
			}
	
			if (ChNum == 3) {
				run("Merge Channels...", "c1=[source #1] c2=[source #2] c3=[source #3] create");
				Stack.setChannel(1);
				run("Blue");
				Stack.setChannel(2);
				run("Green");
				Stack.setChannel(3);
				run("Red");
			}
	
			if (ChNum == 4) {
				run("Merge Channels...", "c1=[source #1] c2=[source #2] c3=[source #3] c4=[source #4] create");
				Stack.setChannel(1);
				run("Blue");
				Stack.setChannel(2);
				run("Green");
				Stack.setChannel(3);
				run("Red");
				Stack.setChannel(4);
				run("Magenta");
			}
		}
		
		// SAVE
		saveAs("Tiff", pathin + "Enhanced/"+Tif_Title);

		
		close();
		endtime = getTime();
		dif = (endtime-starttime)/1000;
		print("Processing time =", dif, "seconds");
		
	}
}	

function closewindow(windowname) {
	if (isOpen(windowname)) { 
      		 selectWindow(windowname); 
       		run("Close"); 
  		} 
}

function collectGarbage2(itr){
	setBatchMode(false);
	wait(1000);
	for(i=0; i<itr; i++){
		wait(100);
		run("Collect Garbage");
		call("java.lang.System.gc");
		}
	setBatchMode(true);
}

function cleanupROI() {
	CountROImain=roiManager("count"); 
		if (CountROImain == 1) {
			roiManager("delete");
			CountROImain=0;
		} else if (CountROImain > 1) {
			ROIarrayMain=newArray(CountROImain); 
			for(n=0; n<CountROImain;n++) { 
	       		ROIarrayMain[n] = n; 
				} 
			roiManager("Select", ROIarrayMain);
			roiManager("Combine");
			roiManager("Delete");
			ROIarrayMain=newArray(0);
			CountROImain=0;
		}		
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

function subtitle(imagename){
	nl=lengthOf(imagename);
	nl2=nl-4;
	Sub_Title=substring(imagename,0,nl2);
	return Sub_Title;
}
function num2array(str,delim){
	arr = split(str,delim);
	for(i=0; i<arr.length;i++) {
		arr[i] = parseInt(arr[i]);
	}

	return arr;
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