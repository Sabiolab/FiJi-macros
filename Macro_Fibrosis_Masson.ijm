// ============================================================
//  Macro to quantify Masson stainning
//  Modo batch de imagenes
// ============================================================

// --- 1. Selección de carpetas ---
inputDir  = getDirectory("Select the folder with the CZI images");
outputDir = getDirectory("Select the output folder");

rgbDir    = outputDir + "RGB"           + File.separator;
masksDir  = outputDir + "Masks"         + File.separator;
deconvDir = outputDir + "Deconvolution" + File.separator;

if (!File.exists(rgbDir))    File.makeDirectory(rgbDir);
if (!File.exists(masksDir))  File.makeDirectory(masksDir);
if (!File.exists(deconvDir)) File.makeDirectory(deconvDir);

// --- 2. First test the deconvolution parameter with one example image---
thresholdMin = 100;
thresholdMax = 255;
sigmaBlur    = 2;

// --- 3. Inicializar CSV con File.append (se escribe imagen a imagen por si se cuelga) ---
csvPath = outputDir + "Fibrosis_quantification.csv";
// Si el archivo ya existe lo borramos para empezar limpio
if (File.exists(csvPath)) File.delete(csvPath);
File.append("Image,Total_Area_px2,Fibrotic_Area_%", csvPath);

// --- 4. Listar archivos .czi ---
fileList = getFileList(inputDir);
cziCount = 0;
for (i = 0; i < fileList.length; i++) {
    if (endsWith(toLowerCase(fileList[i]), ".czi")) cziCount++;
}
if (cziCount == 0) exit("No se encontraron archivos .czi en la carpeta seleccionada.");

print("Archivos CZI encontrados: " + cziCount);
setOption("BlackBackground", true);

// --- 5. Bucle principal ---
processed = 0;

for (i = 0; i < fileList.length; i++) {

    fileName = fileList[i];
    if (!endsWith(toLowerCase(fileName), ".czi")) continue;

    baseName = File.getNameWithoutExtension(fileName);
    filePath = inputDir + fileName;

    print("\n[" + (processed+1) + "/" + cziCount + "] Procesando: " + fileName);

    // 5a. Abrir CZI como composite
    run("Bio-Formats Importer", "open=[" + filePath + "] "
    + "autoscale view=Hyperstack stack_order=XYCZT");
    
    run("Make Composite");
    run("Stack to RGB");

    if (nImages == 0) {
        print("  ERROR: no se pudo abrir " + fileName + ". Saltando.");
        continue;
    }

    compositeTitle = getTitle();

    // 5b. Aplanar a RGB y guardar
    run("Flatten");
    rgbTitle = getTitle();
    rgbPath  = rgbDir + baseName + "_RGB.tif";
    saveAs("Tiff", rgbPath);
    rgbTitle = getTitle();  // recapturar tras saveAs
    print("  RGB guardado: " + rgbPath);

    // Cerrar composite original (el .czi no se modifica)
    if (isOpen(compositeTitle)) {
        selectWindow(compositeTitle);
        close();
    }

    // 5c. Deconvolución sobre la imagen RGB activa
    selectWindow(rgbTitle);
    run("Colour Deconvolution", "vectors=[FastRed FastBlue DAB]");

    // Guardar los tres canales
    deconvNames = newArray(
        rgbTitle + "-(Colour_1)",
        rgbTitle + "-(Colour_2)",
        rgbTitle + "-(Colour_3)"
    );
    for (d = 0; d < 3; d++) {
        if (isOpen(deconvNames[d])) {
            selectWindow(deconvNames[d]);
            saveAs("Tiff", deconvDir + baseName + "_deconv_ch" + (d+1) + ".tif");
            deconvNames[d] = getTitle();  // recapturar tras saveAs
        }
    }

    // 5d. Buscar canal 2 (azul/colágeno) de forma robusta
    ch2Found = false;
    for (w = 1; w <= nImages; w++) {
        selectImage(w);
        t = getTitle();
        if (indexOf(t, baseName + "_deconv_ch2") >= 0 ||
            indexOf(t, "Colour_2") >= 0) {
            ch2Found = true;
            break;
        }
    }

    if (!ch2Found) {
        print("  ERROR: canal 2 no encontrado para " + fileName + ". Saltando.");
        close("*");
        continue;
    }

    // 5e. Generar máscara de fibrosis
    rename("ch2_work");
    run("Invert");
    run("Gaussian Blur...", "sigma=" + sigmaBlur);
    setThreshold(thresholdMin, thresholdMax);
    run("Convert to Mask");

    maskPath = masksDir + baseName + "_FibrosisMask.tif";
    save(maskPath);
    print("  Máscara guardada: " + maskPath);

    // 5f. Quantification — Area & Area%
    run("Set Measurements...", "area area_fraction limit display redirect=None decimal=4");
    run("Measure");

    lastRow      = nResults - 1;
    measArea     = getResult("Area",  lastRow);
    measAreaFrac = getResult("%Area", lastRow);

    // Escribir resultado directamente en el CSV (imagen a imagen)
    File.append(baseName + "," + measArea + "," + measAreaFrac, csvPath);

    print("  Área total (px²): " + measArea + " | Área fibrótica (%): " + measAreaFrac);

    close("*");
    run("Clear Results");
    processed++;
}

// --- 6. Resumen final ---
print("\n=== PROCESAMIENTO COMPLETADO ===");
print("Imágenes procesadas: " + processed + "/" + cziCount);
print("CSV saved at " + csvPath);
