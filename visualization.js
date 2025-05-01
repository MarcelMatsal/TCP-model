/*
  Script for visualizing TCP model in Sterling.
*/

const stage = new Stage();
var currentState = 0;

const NODE_SIZE = width / 3;
const nodes = Node.atoms();
const totalNodes = nodes.length;
const margin = 50;
const availableWidth = width - 2 * margin;
const spacing = availableWidth / totalNodes;

// We the elements of nodes that we keep track of in the visualization.
const nodeElements = {
  "nodeLabels": [],
  "nodeBoxes": [],
};

const nodePositions = {}

const stateColors = {
  Closed0: "#e63946",       // Red
  SynSent0: "#f4a261",      // Orange
  SynReceived0: "#2a9d8f",  // Teal
  Established0: "#457b9d",  // Blue
};


function currentStateToString() {
  return `Current State: ${currentState}`;
}

// Resetting the labels for each node on change of state.
function updateNodes() {
  nodeElements.nodeLabels.forEach((label, idx) => {
    label.setText(`Node ${idx}: ${getCurStateText(idx)}`);
  });
  nodeElements.nodeBoxes.forEach((box, idx) => {
    box.setColor(stateColors[getCurStateText(idx)]);
  });
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
  coords: { x: 300, y: 510 },
  fontSize: 20,
  fontWeight: "Bold",
  color: "black",
});
stage.add(state_label);

// Previous Button
var prev_button = new TextBox({
  text: "▬",
  color: "gray",
  coords: { x: 225, y: 550 },
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
  coords: { x: 225, y: 570 },
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
  coords: { x: 375, y: 550 },
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
  coords: { x: 375, y: 570 },
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



function getCurStateText(idx) {
  const instance = instances[currentState];
  const node_atom = instance.atoms().filter((atom) => atom.id() === `Node${idx}`)[0];
  return node_atom.curState.toString();
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
  const centerX = margin + spacing * idx + spacing / 2;
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

  const node_label = new TextBox({
    text: () => `Node ${idx}: ${getCurStateText(idx)}`,
    coords: { x: centerX, y: centerY - NODE_SIZE / 3 },
    fontSize: 15,
    fontWeight: "Bold",
    color: "black",
  });
  stage.add(node_label);
  nodeElements.nodeBoxes.push(colorBox);
  nodeElements.nodeLabels.push(node_label);

  nodePositions[idx] = [centerX, centerY]
});

stage.render(svg);