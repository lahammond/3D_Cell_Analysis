# 3D Cell Analysis
[![DOI](https://zenodo.org/badge/278457466.svg)](https://zenodo.org/badge/latestdoi/278457466)

Cellular Imaging | Zuckerman Institute, Columbia University - https://www.cellularimaging.org

ImageJ macros for 3D region isolation, enhancement, and cell analysis.

##Installation

Download BrainJ.jar and copy into your ImageJ plugins folder

##Use

1. Run "1 3D Region Extraction and Enhancement"
2. Follow the prompts to extract an ROI and substack as required. Considerng using CLAHE for local contrast enhancement in difficult samples.
3. Run "2 3D Cell Counter"
4. Use options to adjust detection settings and/or redirect intensity measurements to specific channels. If images have been enhanced with CLAHE, intensity measurements will not reflect true intensity.

##Citation

If you use this in your work please cite as below:

Luke Hammond. (2022). lahammond/3D_Cell_Analysis: (v1.0.1). Zenodo. https://doi.org/10.5281/zenodo.6212003
