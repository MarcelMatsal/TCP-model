/*
  Script for visualizing TCP model in Sterling.
*/

const stage = new Stage();
var currentState = 0;

const NODE_SIZE = width / 3;
const NETWORK_POS = [width / 2 - 50, height / 5]
const nodes = Node.atoms();
const totalNodes = nodes.length;
const spacing = width / totalNodes;

// We the elements of nodes that we keep track of in the visualization.
const nodeElements = {
  "nodeLabels": [],
  "nodeBoxes": [],
};

const networkPackets = []

const nodeSendBuffers = {}
const nodeReceiveBuffers = {}
const nodePositions = {}

const stateColors = {
  Closed0: "#e63946",       // Red
  SynSent0: "#f4a261",      // Orange
  SynReceived0: "#2a9d8f",  // Teal
  Established0: "#457b9d",  // Blue
};


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
  nodes.forEach((_, idx) => getCurrentBufferData(idx))

  createPacketsInNetwork(instances[currentState].atoms().filter((atom) => atom.id() === `Network0`)[0]);
}

function createPacketsInNetwork(network) {
  networkPackets.forEach((pack) => {
    stage.remove(pack)
  });

  const netLabel = new TextBox({
    text: network.packets.toString(),
    coords: {
      x: NETWORK_POS[0] + 50,
      y: NETWORK_POS[1] + 100,
    },
    fontSize: 12,
    color: "black",
  });
  networkPackets.push(netLabel)
  stage.add(netLabel);
}

// Thank you to Sarah Ridley for these functions!
function incrementState() {
  var lastState = instances.length - 1;
  if (currentState < lastState) {
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
var stateLabel = new TextBox({
  text: () => currentStateToString(),
  coords: { x: width / 2, y: 510 },
  fontSize: 20,
  fontWeight: "Bold",
  color: "black",
});
stage.add(stateLabel);

// Previous Button
var prevButton = new TextBox({
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
stage.add(prevButton);

var prevButtonLabel = new TextBox({
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
stage.add(prevButtonLabel);

// Next Button
var nextButton = new TextBox({
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
stage.add(nextButton);

var nextButtonLabel = new TextBox({
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
stage.add(nextButtonLabel);

const networkLabel = new TextBox({
  text: "Network",
  coords: {
    x: NETWORK_POS[0] + 50,
    y: NETWORK_POS[1],
  },
  fontSize: 14,
  color: "black",
});
stage.add(networkLabel);
const networkBox = new Rectangle({
  coords: {
    x: NETWORK_POS[0],
    y: NETWORK_POS[1] + 10,
  },
  width: 100,
  height: 200,
  color: "whitesmoke",
});
stage.add(networkBox);

function getNodeInstanceFromId(idx) {
  const instance = instances[currentState];
  return instance.atoms().filter((atom) => atom.id() === `Node${idx}`)[0];
}

function getCurStateText(idx) {
  const nodeAtom = getNodeInstanceFromId(idx)
  return nodeAtom.curState.toString();
}

function getCurrentBufferData(idx) {
  const nodeAtom = getNodeInstanceFromId(idx)
  getSpecificBufferData(idx, nodeSendBuffers, nodeAtom.sendBuffer);
  getSpecificBufferData(idx, nodeReceiveBuffers, nodeAtom.receiveBuffer, 100);
}

function getSpecificBufferData(idx, nodeBufferDict, buff, offset = 0) {
  if (!nodeBufferDict[idx]) {
    nodeBufferDict[idx] = [];
  } else {
    nodeBufferDict[idx].forEach((label) => {
      stage.remove(label);
    });
  }

  var count = 0;
  buff.tuples().map((packet) => {
    const packAtom = packet.atoms()[0]
    var color = "black";
    if (packAtom.in(DataPacket)) {
      color = "green";
    }
    const buffLabel = new TextBox({
      text: packAtom.toString(),
      coords: {
        x: nodePositions[idx][0],
        y: nodePositions[idx][1] + (10 * count) + offset,  // stack inside the SendBuffer box
      },
      fontSize: 10,
      color: color,
    });
    stage.add(buffLabel);
    count += 1;
    // We add the label to the nodeSendBuffers array:
    nodeBufferDict[idx].push(buffLabel);
  });
}


function genBufferBox(centerX, centerY, yOffset, label, labelOffsetY = -15) {
  const bufferX = centerX - (NODE_SIZE - 15) / 2;
  const bufferY = centerY + yOffset;

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

nodes.forEach((_, idx) => {
  const centerX = spacing * idx + spacing / 2;
  const centerY = height / 4;


  const colorBox = new Rectangle({
    coords: { x: centerX - NODE_SIZE / 2, y: centerY - NODE_SIZE / 2 },
    width: NODE_SIZE,
    height: NODE_SIZE * 1.25,
    color: stateColors[getCurStateText(idx)],
  });
  stage.add(colorBox);

  genBufferBox(centerX, centerY, -25, "SendBuffer");
  genBufferBox(centerX, centerY, 75, "ReceiveBuffer");
  getCurrentBufferData(idx);

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
  nodePositions[idx] = [centerX, centerY]
});


stage.render(svg);
