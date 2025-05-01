/*
  Script for visualizing TCP model in Sterling.
*/

const stage = new Stage();
var currentState = 0;

// We the elements of nodes that we keep track of in the visualization.
const nodeElements = {
  "nodeLabels": [],
  "nodeBoxes": [],
};

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

const nodes = Node.atoms()
nodes.forEach((node, idx) => {
  const x = width / 3 + idx * (width / 2);
  const y = 60;

  const colorBox = new Rectangle({
    coords: { x: x - 75, y: y - 25 },
    width: 200,
    height: 50,
    color: stateColors[getCurStateText(idx)],
  });
  stage.add(colorBox);

  var node_label = new TextBox({
    text: () => `Node ${idx}: ${getCurStateText(idx)}`,
    coords: { x: x, y: y },
    fontSize: 15,
    fontWeight: "Bold",
    color: "black",
  });
  stage.add(node_label);
  nodeElements.nodeBoxes.push(colorBox);
  nodeElements.nodeLabels.push(node_label);
});

stage.render(svg);
