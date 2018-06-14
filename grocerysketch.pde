import com.temboo.core.*;
import com.temboo.Library.Google.Gmail.*;
import processing.serial.*;

Serial myPort;
String ardVal = "helloWorld"; //string recieved from arduino

PFont font20;
PFont font14;

int rotaryCount;
int position;

//dimensions for a 4x5 table for 25 orders max
int columnWidth = 200;
int rowHeight = 40;

int itemX = 10; 
int itemY = 25;
int quantX = 160; 
int quantY = 25;

boolean update;

String[] itemsTest = {"tomatoes", "potatoes", "wine", "pasta", "mushrooms", "garlic", "pesto"};
String[] quantTest = {"800g", "1 kg", "70cl", "400g", "400g", "x1", "x1"};
int[] orderTest = {1, 1, 0, 1, 1, 0, 1};

// Create a session using your Temboo account application details
TembooSession session = new TembooSession("br5m", "myFirstApp", "i387O73lzZPZgEYScA65WgLVRo2u1VVO");

void setup() {
  background(40, 33, 54);
  size(800, 480);
  noStroke();
  fill(255);
  rect(0, 260, 800, 220);
  fill(230);
  rect(0, 200, 800, 60);

  font20 = loadFont("RobotoCondensed-Regular-20.vlw");
  font14 = loadFont("RobotoCondensed-Regular-14.vlw");
  
  printArray(Serial.list());
  String portName = Serial.list()[0]; //choose number to match port
  myPort = new Serial(this, portName, 9600); //initiate connection thingy
  
  /*String[] items = loadStrings("items.txt");
   println("there are " + items.length + " lines");
   for (int i = 0 ; i < items.length; i++) {
   println(items[i]);
   }
   
   String[] quantities = loadStrings("quantities.txt");
   println("there are " + quantities.length + " quantities");
   for (int i = 0 ; i < quantities.length; i++) {
   println(quantities[i]);
   }*/
}

void draw() { 
  //read serial
    if (myPort.available() > 0) {
    ardVal = trim(myPort.readStringUntil('\n'));
    println(ardVal);
  } 
  
  //encoder control
  if (ardVal != null) {
    if (ardVal.equals("encoderUp")) {
      rotaryCount++;
      println("rotaryCount++");
    }
    if (ardVal.equals("encoderDown")) {
      rotaryCount--;
      println("rotaryCount--");
    }
  }
  
  //transate encoder value to position
  position = (abs(rotaryCount % 21)) % itemsTest.length;
  
  //slider control
  if (ardVal != null) {
    if (ardVal.equals("sliderUp")) {
      if (itemsTest.length < 19) {
        addItem();
        println("itemUp");
      }
    }
    if (ardVal.equals("sliderDown")) {
      printItem();
      println("itemDown");
    }
  }
  
  //rotary button
  if (ardVal != null) {
    if (ardVal.equals("buttonPressed")) {
      println("toggle item");
      selectItem();
    }
    if (ardVal.equals("buttonDelete")) {
      println("delete item");
      deleteItem();
    }
  }
  
  //draw UI
    //drawing the UI
  fill(40, 33, 54);
  rect(0, 0, 800, 200);
  drawColumn();
  drawNav();
  
  //reset serial input
  ardVal = null;
  
}

void keyPressed() {

  //rotary encoder emulator
  if (key == CODED) {
    if (keyCode == UP) {
      rotaryCount++;
      //println("Rotary counter: "+rotaryCount);
    }
    if (keyCode == DOWN) {
      rotaryCount--;
      //println("Rotary counter: "+rotaryCount);
    }
  }

  //transate encoder value to position
  position = (abs(rotaryCount % 21)) % itemsTest.length;
  println("encoder position: "+position);

  //rotary TOGGLE button emulator
  if (key == CODED) {
    if (keyCode == SHIFT) {
      println("item added to / removed from order list");
      selectItem();
    }
  }

  //rotary DELETE button emulator
  if (key == BACKSPACE) {
    println("item deleted");
    deleteItem();
  }
  
  //transate encoder value to position
  position = (abs(rotaryCount % 21)) % itemsTest.length;

  //motorized slider emulator
  if (key == CODED) {
    if (keyCode == RIGHT) {
      if (itemsTest.length < 19) {
        addItem();
        println("item to digital space");
      }
    }
    if (keyCode == LEFT) {
      println("item to physical space");
    }
  }
  
  //email emulator
  if(key == 's'){
    runSendEmailChoreo();
  }

  //drawing the UI
  fill(40, 33, 54);
  rect(0, 0, 800, 200);
  drawColumn();
  drawNav();
}

void drawColumn() {
  int columnN = 0; 
  int rowN = 0;
  for (int i = 0; i < itemsTest.length && i < 19; i++) {
    if (i % 5 == 0 && i != 0) {
      columnN++; 
      rowN = 0;
    }
    if (orderTest[i] == 1) {
      fill(254, 40, 82);
    }
    if (orderTest[i] == 0) {
      fill(249, 243, 245);
    }
    text(itemsTest[i], itemX+(columnN*columnWidth), itemY+(rowN*rowHeight));
    text(quantTest[i], quantX+(columnN*columnWidth), quantY+(rowN*rowHeight));
    rowN++;
  }
}

void drawNav() {
  int posX = int(position/5) * columnWidth;
  int posY = (position % 5) * rowHeight;
  fill(249, 243, 245);
  rect(posX, posY, columnWidth, rowHeight);
  if (orderTest[position] == 1) {
    fill(254, 40, 82);
  }
  if (orderTest[position] == 0) {
    fill(0);
  }
  text(itemsTest[position], posX+itemX, posY+itemY);
  text(quantTest[position], posX+quantX, posY+quantY);
}

void addItem() {
  String[] fetchItem = loadStrings("newItem.txt");
  String newItem = fetchItem[0];
  fetchItem = null;
  itemsTest = append(itemsTest, newItem);

  String[] fetchQuant = loadStrings("newQuant.txt");
  String newQuant = fetchQuant[0];
  fetchQuant = null;
  quantTest = append(quantTest, newQuant);

  orderTest = append(orderTest, 0);
}

void printItem() {
  String[] fetchItem = loadStrings("newItem.txt");
  String newItem = fetchItem[0];
  fetchItem = null;
  myPort.write(newItem);
  println("to printer: "+newItem);
}

void deleteItem() { 
  for(int i = 0; i < (itemsTest.length -1); i++){
    if(i >= position){
      itemsTest[i] = itemsTest[i+1];
      quantTest[i] = quantTest[i+1];
      orderTest[i] = orderTest[i+1];
    }
  }
  if(itemsTest.length == 1){
    itemsTest[0] = "Item"; quantTest[0] = "-"; orderTest[0] = 0;
  }else{
    itemsTest = shorten(itemsTest); quantTest = shorten(quantTest); orderTest = shorten(orderTest);
  }
  position--;
}

void selectItem() {
  if(orderTest[position] == 1) {
    orderTest[position] = 0;
    return;
  }
  if(orderTest[position] == 0) {
    orderTest[position] = 1;
  }
}

void runSendEmailChoreo() {
  // Create the Choreo object using your Temboo session
  SendEmail sendEmailChoreo = new SendEmail(session);

  // The name of your Temboo Google Profile 
  String googleProfile = "gmail4processing";
 
  // Set Profile  
  sendEmailChoreo.setCredential(googleProfile);

  // Declare the strings for your email
  String fromAddress = "Groceries <bramjamin@gmail.com>";
  String toAddress = "bramjamin@gmail.com";
  String subject = hour()+":"+minute()+" groceries";
  
  String[] groceryList = new String[itemsTest.length];
  
  for(int i = 0; i < itemsTest.length; i++){
    if(orderTest[i] == 1){
      println(i);
      groceryList[i] = "[ ] "+itemsTest[i]+" - "+quantTest[i];
    }
  }
  
  String messageBody = join(groceryList, "\n");

  // Set inputs
  sendEmailChoreo.setMessageBody(messageBody);
  sendEmailChoreo.setSubject(subject);
  sendEmailChoreo.setFromAddress(fromAddress);
  sendEmailChoreo.setToAddress(toAddress);

  // Run the Choreo and store the results
  SendEmailResultSet sendEmailResults = sendEmailChoreo.run();
  
  // Print results
  println(sendEmailResults.getSuccess());

}
