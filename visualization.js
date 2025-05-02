/*
  Script for visualizing TCP model in Sterling.
*/

const stage = new Stage();
var currentState = 0;

const NODE_SIZE = width / 3;
const nodes = Node.atoms();
const totalNodes = nodes.length;
const spacing = width / totalNodes;

// We the elements of nodes that we keep track of in the visualization.
const nodeElements = {
  "nodeLabels": [],
  "nodeBoxes": [],
  "nodeSendBuffers": [],
};

const nodePositions = {}

const stateColors = {
  Closed0: "#e63946",       // Red
  SynSent0: "#f4a261",      // Orange
  SynReceived0: "#2a9d8f",  // Teal
  Established0: "#457b9d",  // Blue
};

function fam(expr) {
  if (!expr.empty()) return expr.tuples()[0].atoms()[0];
  return "none";
}


function currentStateToString() {
  return `Current Step: ${currentState}`;
}

// Resetting the labels for each node on change of state.
function updateNodes() {
  nodeElements.nodeLabels.forEach((label, idx) => {
    label.setText(`Node ${idx}: ${getCurStateText(idx)}`);
  });
  nodeElements.nodeBoxes.forEach((box, idx) => {
    box.setColor(stateColors[getCurStateText(idx)]);
  });
  nodeElements.nodeSendBuffers.forEach((label, idx) => {
    label.setText(getCurSendBufferData(idx))
  })
}

// Thank you to Sarah Ridley for these functions!
function incrementState() {
  var last_state = instances.length - 1;
  if (currentState < last_state) {
    currentState += 1;
  }
  updateNodes();
  stage.render(svg);
}
function decrementState() {
  if (currentState != 0) {
    currentState -= 1;
  }
  updateNodes();
  stage.render(svg);
}

// State label
var state_label = new TextBox({
  text: () => currentStateToString(),
  coords: { x: width / 2, y: 510 },
  fontSize: 20,
  fontWeight: "Bold",
  color: "black",
});
stage.add(state_label);

// Previous Button
var prev_button = new TextBox({
  text: "▬",
  color: "gray",
  coords: { x: width / 2 - 75, y: 550 },
  fontSize: 200,
  events: [
    {
      event: "click",
      callback: () => {
        decrementState();
      },
    },
  ],
});
stage.add(prev_button);

var prev_button_label = new TextBox({
  text: "Previous State",
  coords: { x: width / 2 - 75, y: 570 },
  fontSize: 15,
  fontWeight: "Bold",
  color: "white",
  events: [
    {
      event: "click",
      callback: () => {
        decrementState();
      },
    },
  ],
});
stage.add(prev_button_label);

// Next Button
var next_button = new TextBox({
  text: "▬",
  color: "gray",
  coords: { x: width / 2 + 75, y: 550 },
  fontSize: 200,
  events: [
    {
      event: "click",
      callback: () => {
        incrementState();
      },
    },
  ],
});
stage.add(next_button);

var next_button_label = new TextBox({
  text: "Next State",
  coords: { x: width / 2 + 75, y: 570 },
  fontSize: 15,
  fontWeight: "Bold",
  color: "white",
  events: [
    {
      event: "click",
      callback: () => {
        incrementState();
      },
    },
  ],
});
stage.add(next_button_label);

function getNodeInstanceFromId(idx) {
  const instance = instances[currentState];
  return instance.atoms().filter((atom) => atom.id() === `Node${idx}`)[0];
}


function getCurStateText(idx) {
  const nodeAtom = getNodeInstanceFromId(idx)
  return nodeAtom.curState.toString();
}

function getCurSendBufferData(idx) {
  const nodeAtom = getNodeInstanceFromId(idx)
  return nodeAtom.sendBuffer.toString()
}

function genBufferBox(centerX, centerY, y_offset, label, labelOffsetY = -15) {
  const bufferX = centerX - (NODE_SIZE - 15) / 2;
  const bufferY = centerY + y_offset;

  const bufferBox = new Rectangle({
    coords: {
      x: bufferX,
      y: bufferY,
    },
    width: NODE_SIZE - 15,
    height: NODE_SIZE / 3,
    color: "whitesmoke",
  });
  stage.add(bufferBox);

  const labelBox = new TextBox({
    text: label,
    coords: { x: bufferX + (NODE_SIZE - 15) / 2, y: bufferY + labelOffsetY },
    fontSize: 12,
    color: "white",
    fontWeight: "bold",
  });
  stage.add(labelBox);
}

nodes.forEach((node, idx) => {
  const centerX = spacing * idx + spacing / 2;
  const centerY = height / 4;

  const boxWidth = NODE_SIZE;
  const boxHeight = NODE_SIZE;

  const colorBox = new Rectangle({
    coords: { x: centerX - boxWidth / 2, y: centerY - boxHeight / 2 },
    width: boxWidth,
    height: boxHeight * 1.25,
    color: stateColors[getCurStateText(idx)],
  });
  stage.add(colorBox);

  genBufferBox(centerX, centerY, -25, "SendBuffer");
  genBufferBox(centerX, centerY, 75, "ReceiveBuffer");


  // For every packet in a node.sendBuffer, we make a label
  const sendBufferLabel = new TextBox({
    text: getCurSendBufferData(idx),  // or customize this if needed
    coords: {
      x: centerX,
      y: centerY,  // stack inside the SendBuffer box
    },
    fontSize: 10,
    color: "black",
  });
  stage.add(sendBufferLabel)


  const nodeLabel = new TextBox({
    text: () => `Node ${idx}: ${getCurStateText(idx)}`,
    coords: { x: centerX, y: centerY - NODE_SIZE / 3 },
    fontSize: 15,
    fontWeight: "Bold",
    color: "black",
  });
  stage.add(nodeLabel);

  nodeElements.nodeBoxes.push(colorBox);
  nodeElements.nodeLabels.push(nodeLabel);
  nodeElements.nodeSendBuffers.push(sendBufferLabel)
  nodePositions[idx] = [centerX, centerY]
});

stage.render(svg);
