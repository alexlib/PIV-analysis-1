## PIV-analysis documentation

Particle Image Velocimetry (PIV) package developed in the Stramer Lab (King's College London, UK).

This analysis should be run on the output of PIV codes, which can be found [here](https://github.com/stemarcotti/PIV). Tested on MATLAB v2018B.

### Divergence analysis

Calculate divergence heatmap with the script called **[divergence_heatmap.m]**.

- input requested to the user:
  + folder containing **[cb#\_m.tif]** and PIV output (e.g. _[cell1]_)
  + name for the output stamp to be appended to all saved output files (e.g. [output_name]: cell1); need to be the same assigned when running **[happy_piv.m]**!
  + the movie ID (# in **[cb#\_m.tif]**)
- output: this script returns the refined stack **[divergence_heatmap_(ouput_name).tif]** (in folder [images]) showing the negative divergence for each frame

### Principal Strain Rate analysis

Calculate principal strain rate heatmap with the script called **[principal_strain_rate_heatmap.m]**.

- input requested to the user:
  + folder containing **[cb#\_m.tif]** and PIV output (e.g. _[cell1]_)
  + name for the output stamp to be appended to all saved output files (e.g. [output_name]: cell1); need to be the same assigned when running **[happy_piv.m]**!
  + the movie ID (# in **[cb#\_m.tif]**)
- output: this script returns the refined stack **[principal_strain_rate_heatmap_(ouput_name).tif]** (in folder [images]) showing the negative principal strain rate for each frame

### Actin Turnover analysis

Calculate actin turnover heatmap with the script called **[actin_turnover_heatmap.m]**.    
See [here](https://www.ncbi.nlm.nih.gov/pubmed/20485438) and [here](https://www.ncbi.nlm.nih.gov/pubmed/15210979) for references.

- input requested to the user:
  + folder containing **[cb#\_m.tif]** and PIV output (e.g. _[cell1]_)
  + name for the output stamp to be appended to all saved output files (e.g. [output_name]: cell1); need to be the same assigned when running **[happy_piv.m]**!
  + the movie ID (# in **[cb#\_m.tif]**)
- output: this script returns the refined stack **[actin_turnover_heatmap_(ouput_name).tif]** (in folder [images]) showing the negative actin turnover for each frame

### Flow streamline analysis

Calculate streamlines for the flow tracked by PIV with the script called **[streamlines_plot.m]**.

- input requested to the user:
  + folder containing **[cb#\_m.tif]** and PIV output (e.g. _[cell1]_)
  + name for the output stamp to be appended to all saved output files (e.g. [output_name]: cell1); need to be the same assigned when running **[happy_piv.m]**!
  + the movie ID (# in **[cb#\_m.tif]**)
- output: this script returns the refined stacks **[streamlines_(ouput_name).tif]** and **[end_points_(ouput_name).tif]** (in folder [images]) and the file **[flow_streamlines_endpts_(output_name).mat]** (in folder [data]). The figures are not shown during the script run. The first stack shows in green the flow streamlines for each frame; the second stack shows with magenta dots the locations of streamline end points (saved in the .mat file), the dots size is proportional to the number of streamlines ending in a given location.
