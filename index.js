function convertTemperature(temperature, unitFrom, unitTo) {
    // Convert to Celsius first
    let celsiusTemp;
    if (unitFrom === "Celsius") {
      celsiusTemp = temperature;
    } else if (unitFrom === "Fahrenheit") {
      celsiusTemp = (temperature - 32) * 5 / 9;
    } else if (unitFrom === "Kelvin") {
      celsiusTemp = temperature - 273.15;
    } else {
      return "Invalid input unit";
    }
    
    // Convert from Celsius to the desired unit
    let outputTemp;
    if (unitTo === "Celsius") {
      outputTemp = celsiusTemp;
    } else if (unitTo === "Fahrenheit") {
      outputTemp = celsiusTemp * 9 / 5 + 32;
    } else if (unitTo === "Kelvin") {
      outputTemp = celsiusTemp + 273.15;
    } else {
      return "Invalid output unit";
    }
    
    return outputTemp;
  }

  let fahrenheitTemp = 68;
let convertedTemp = convertTemperature(fahrenheitTemp, "Fahrenheit", "Celsius");
console.log(convertedTemp); // Output: 20