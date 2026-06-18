// ============================================================
//  IHC DAB-Positive Area Quantification Macro
// ============================================================

// TRESHOLD AT 111 FOR LY6G/6C , 130 FOR NK1.1 AND AT 150 FOR MPO

var DAB_THRESHOLD_UPPER = 150;

macro "IHC DAB Quantification [F5]" {
    run("Clear Results");
    setBatchMode(true);

    dir = getDirectory("Selecciona la carpeta con las imagenes .tif");
    list = getFileList(dir);
    maskDir = dir + "mask" + File.separator;
    File.makeDirectory(maskDir);

    csvPath = dir + "DAB_Area.csv";
    File.saveString("Label,White_Area_px,Total_Area_px,White_Area_pct", csvPath);

    for (i = 0; i < list.length; i++) {
        name = list[i];
        if (!endsWith(toLowerCase(name), ".tif") && !endsWith(toLowerCase(name), ".tiff")) continue;

        open(dir + name);
        imgTitle = getTitle();

        run("Colour Deconvolution", "vectors=[H DAB]");
        dabTitle = imgTitle + "-(Colour_2)";
        if (isOpen(dabTitle)) selectWindow(dabTitle); else selectImage(getImageID() + 2);

        run("8-bit");
        run("Gaussian Blur...", "sigma=1");

        setThreshold(0, DAB_THRESHOLD_UPPER);
        run("Convert to Mask", "background=Dark black");

        maskName = replace(name, ".tif", "_mask.tif");
        maskName = replace(maskName, ".tiff", "_mask.tif");
        saveAs("Tiff", maskDir + maskName);

        // Calcular área blanca a partir de la máscara binaria (blanco=255, negro=0)
        getRawStatistics(totalPixels, meanVal);
        whiteArea = round(totalPixels * (meanVal / 255.0));
        pct = whiteArea / totalPixels * 100.0;

        // Escribir directamente al CSV
        line = imgTitle + "," + whiteArea + "," + totalPixels + "," + d2s(pct, 4) + "\n";
        File.append(line, csvPath);

        // Limpieza de ventanas
        run("Close All");
    }

    setBatchMode(false);
    showMessage("Listo!", "Procesadas " + list.length + " imagenes.\nResultados en: " + csvPath);
}
