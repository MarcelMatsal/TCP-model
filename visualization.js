/*
  Script for visualizing TCP model in Sterling.
*/

const stage = new Stage();
stage.backgroundColor = "white"
var currentState = 0;

const NODE_SIZE = width / 3;
const NETWORK_POS = [width / 2 - 100, height / 7]
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

function getPacketColor(packet) {
  if (packet.in(DataPacket)) {
    return "#E49DFB"
  } else if (packet.in(AckPacket)) {
    return "#B698D7"
  } else if (packet.in(FinPacket)) {
    return "#986CC6"
  }
  return "white"
}


function currentStateToString() {
  return `Current Step: ${currentState}`;
}

// Resetting the labels for each node on change of state.
function updateNodes() {
  nodeElements.nodeLabels.forEach((label, idx) => {
    label.setText(`Node ${idx}: ${getCurStateText(idx)}`);
  });

  nodes.forEach((_, idx) => getCurrentBufferData(idx))

  createPacketsInNetwork(instances[currentState].atoms().filter((atom) => atom.id() === `Network0`)[0]);
}

function getPacketDisplayName(packAtom) {
  packetPresent = packAtom.toString()
  if (packAtom.in(DataPacket)) {
    packetPresent += " (Data)"
  } else if (packAtom.in(AckPacket)) {
    packetPresent += " (Ack)"
    color = "#B698D7"
  } else if (packAtom.in(FinPacket)) {
    packetPresent += " (Fin)"
    color = "#986CC6"
  }
  if (packAtom.pSeqNum.toString() != "") {
    packetPresent += ` Seq: ${packAtom.pSeqNum.toString()} Ack: ${packAtom.pAckNum.toString()}`
  }
  return packetPresent
}


function createPacketsInNetwork(network) {
  networkPackets.forEach((pack) => {
    stage.remove(pack)
  });

  network.packets.tuples().map((packet) => {
    const packAtom = packet.atoms()[0]

    const packBox = new Rectangle({
      coords: {
        x: NETWORK_POS[0],
        y: NETWORK_POS[1] + 88,
      },
      color: getPacketColor(packAtom),
      width: 200,
      height: 25
    });
    stage.add(packBox);
    networkPackets.push(packBox)

    const packLabel = new TextBox({
      text: getPacketDisplayName(packAtom),
      coords: {
        x: NETWORK_POS[0] + 100,
        y: NETWORK_POS[1] + 100,
      },
      fontSize: 10,
      color: "white",
      fontWeight: "bold"
    });
    networkPackets.push(packLabel)
    stage.add(packLabel);
  });
}

// Thank you to Sarah Ridley for these functions!
function incrementState() {
  var lastState = instances.length - 1;
  if (currentState < lastState) {
    currentState += 1;
  } else {
    currentState = 0
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
  coords: { x: NETWORK_POS[0] + 100, y: 410 },
  fontSize: 16,
  fontWeight: "Bold",
  color: "black",
});
stage.add(stateLabel);

// Previous Button
var prevButton = new TextBox({
  text: "▬",
  color: "#1bb7f5",
  coords: { x: NETWORK_POS[0] + 100 - 75, y: 470 },
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
  coords: { x: NETWORK_POS[0] + 100 - 75, y: 490 },
  fontSize: 15,
  fontWeight: "Bold",
  color: "black",
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
  color: "#1bb7f5",
  coords: { x: NETWORK_POS[0] + 100 + 75, y: 470 },
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
  coords: { x: NETWORK_POS[0] + 100 + 75, y: 490 },
  fontSize: 15,
  fontWeight: "Bold",
  color: "black",
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
    x: NETWORK_POS[0] + 100,
    y: NETWORK_POS[1],
  },
  fontSize: 14,
  fontWeight: "bold",
  color: "black",
});
stage.add(networkLabel);
const networkBox = new Rectangle({
  coords: {
    x: NETWORK_POS[0],
    y: NETWORK_POS[1] + 10,
  },
  width: 200,
  height: 240,
  color: "whitesmoke",
  borderColor: "whitesmoke"
});
stage.add(networkBox);

// Title bar

const titleBox = new Rectangle({
  coords: {
    x: NETWORK_POS[0] + 100 - (width / 2),
    y: NETWORK_POS[1] - 100,
  },
  width: width,
  height: 50,
  color: "#7dcc41",
});
stage.add(titleBox);
const titleLabel = new TextBox({
  text: "TCP Model",
  coords: {
    x: NETWORK_POS[0] + 100,
    y: NETWORK_POS[1] - 75,
  },
  fontSize: 16,
  fontWeight: "Bold",
  color: "black",
});
stage.add(titleLabel);



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

    const packBox = new Rectangle({
      coords: {
        x: nodePositions[idx][0] - 75,
        y: nodePositions[idx][1] + (10 * count) + offset - 12,  // stack inside the SendBuffer box
      },
      color: getPacketColor(packAtom),
      width: 150,
      height: 25
    });
    stage.add(packBox);
    const buffLabel = new TextBox({
      text: getPacketDisplayName(packAtom),
      coords: {
        x: nodePositions[idx][0],
        y: nodePositions[idx][1] + (10 * count) + offset,  // stack inside the SendBuffer box
      },
      fontSize: 10,
      fontWeight: "bold",
      color: "white",
    });
    stage.add(buffLabel);

    count += 1;
    // We add the label to the nodeSendBuffers array:
    nodeBufferDict[idx].push(buffLabel);
    nodeBufferDict[idx].push(packBox);
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
    fontSize: 14,
    color: "#1bb7f5",
    fontWeight: "bold",
  });
  stage.add(labelBox);
}

nodes.forEach((_, idx) => {
  var xOff = 0

  if (idx == 0) {
    xOff = -50
  } else {
    xOff = 50
  }

  const centerX = spacing * idx + spacing / 2 + xOff;
  const centerY = height / 4;



  const colorBox = new Rectangle({
    coords: { x: centerX - NODE_SIZE / 2, y: centerY - NODE_SIZE / 2 },
    width: NODE_SIZE,
    height: NODE_SIZE * 1.25,
    color: "white",
    borderColor: "whitesmoke"
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
