import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { onRequest } from "firebase-functions/v2/https";

initializeApp();

const db = getFirestore();
const maxBottleTextLength = 60;

type BottleColor = "seaGreen" | "amber" | "skyBlue" | "smoke" | "rose";

type ExchangeBottleRequest = {
  text?: string;
  bottleColor?: BottleColor;
  driftedAt?: string;
};

type ReportBottleRequest = {
  bottleID?: string;
};

type BlockBottleSenderRequest = {
  bottleID?: string;
};

type ReturnBottleRequest = {
  bottleID?: string;
};

type StoredBottle = {
  clientID: string;
  text: string;
  bottleColor: BottleColor;
  driftedAt: Timestamp;
  randomKey: number;
  createdAt: FieldValue;
  isReported?: boolean;
  deliveredCount?: number;
  lastReturnedBy?: string;
};

type DeliveredBottle = {
  serverID?: string;
  text: string;
  bottleColor: BottleColor;
  driftedAt: string;
  isFallback?: boolean;
};

const allowedBottleColors = new Set<BottleColor>([
  "seaGreen",
  "amber",
  "skyBlue",
  "smoke",
  "rose"
]);

// Conservative pre-distribution checks for anonymous user-generated content.
// Keep these server-side so older clients receive the same protection.
const unsafeContentPatterns: RegExp[] = [
  /(https?:\/\/|www\.|[\w.-]+@[\w.-]+|\d{2,4}[-\s]\d{2,4}[-\s]\d{3,4})/i,
  /(?:line|instagram|insta|discord|telegram|twitter|tiktok|snapchat|kakao)(?:\s*[:：@＠_-]\s*|\s+id\s*)[a-z0-9._-]{2,}/i,
  /(?:死ね|しね|殺す|ころす|消えろ|自殺|首をつる|リスカ)/i,
  /(?:セックス|性交|裸|ヌード|エロ|猥褻|援助交際)/i,
  /(?:覚醒剤|大麻|麻薬|ドラッグ|犯罪予告|爆破予告)/i,
  /(?:家に来い|会おう|会いたい|住所教え|連絡先教え)/i
];

const fallbackBottles: Array<Omit<DeliveredBottle, "driftedAt">> = [
  {
    text: "知らない駅で降りたら、風だけが先に春でした。",
    bottleColor: "seaGreen",
    isFallback: true
  },
  {
    text: "今日は何も進まなかったけど、月だけはちゃんと出ていました。",
    bottleColor: "skyBlue",
    isFallback: true
  },
  {
    text: "コンビニの灯りに救われる夜が、たまにあります。",
    bottleColor: "amber",
    isFallback: true
  },
  {
    text: "うまく言えなかった言葉を、帰り道で何度も言い直しました。",
    bottleColor: "smoke",
    isFallback: true
  },
  {
    text: "誰かの小さな親切で、一日が少しだけほどけました。",
    bottleColor: "rose",
    isFallback: true
  }
];

export const exchangeBottle = onRequest({ region: "asia-northeast1" }, async (request, response) => {
  if (request.method !== "POST") {
    response.status(405).json({ error: "method-not-allowed" });
    return;
  }

  const uid = await authenticatedUID(request);
  if (!uid) {
    response.status(401).json({ error: "unauthenticated" });
    return;
  }

  const submittedText = cleanText((request.body as ExchangeBottleRequest).text, maxBottleTextLength);
  if (submittedText && containsUnsafeText(submittedText)) {
    response.status(422).json({ error: "unsafe-content" });
    return;
  }

  const bottle = normalizeBottle(request.body as ExchangeBottleRequest, uid);
  if (!bottle) {
    response.status(400).json({ error: "invalid-bottle" });
    return;
  }

  const docRef = await db.collection("bottles").add(bottle);
  const blockedClientIDs = await getBlockedClientIDs(bottle.clientID);
  const deliveredBottle = await findDeliveredBottle(bottle.clientID, docRef.id, bottle.randomKey, blockedClientIDs);

  response.json({
    deliveredBottle: deliveredBottle ?? fallbackDeliveredBottle(bottle)
  });
});

export const reportBottle = onRequest({ region: "asia-northeast1" }, async (request, response) => {
  if (request.method !== "POST") {
    response.status(405).json({ error: "method-not-allowed" });
    return;
  }

  const uid = await authenticatedUID(request);
  if (!uid) {
    response.status(401).json({ error: "unauthenticated" });
    return;
  }

  const body = request.body as ReportBottleRequest;
  const bottleID = cleanText(body.bottleID, 120);
  if (!bottleID) {
    response.status(400).json({ error: "invalid-report" });
    return;
  }

  const bottleRef = db.collection("bottles").doc(bottleID);
  const bottleSnapshot = await bottleRef.get();
  if (!bottleSnapshot.exists) {
    response.status(404).json({ error: "bottle-not-found" });
    return;
  }

  await bottleRef.set({
    isReported: true,
    reportedAt: FieldValue.serverTimestamp(),
    reportCount: FieldValue.increment(1)
  }, { merge: true });

  await db.collection("reports").add({
    bottleID,
    reporterClientID: uid,
    bottleAuthorClientID: (bottleSnapshot.data() as StoredBottle).clientID,
    createdAt: FieldValue.serverTimestamp()
  });

  response.json({ ok: true });
});

export const blockBottleSender = onRequest({ region: "asia-northeast1" }, async (request, response) => {
  if (request.method !== "POST") {
    response.status(405).json({ error: "method-not-allowed" });
    return;
  }

  const uid = await authenticatedUID(request);
  if (!uid) {
    response.status(401).json({ error: "unauthenticated" });
    return;
  }

  const body = request.body as BlockBottleSenderRequest;
  const bottleID = cleanText(body.bottleID, 120);
  if (!bottleID) {
    response.status(400).json({ error: "invalid-block" });
    return;
  }

  const bottleRef = db.collection("bottles").doc(bottleID);
  const bottleSnapshot = await bottleRef.get();
  if (!bottleSnapshot.exists) {
    response.status(404).json({ error: "bottle-not-found" });
    return;
  }

  const bottle = bottleSnapshot.data() as StoredBottle;
  await db.collection("blocks").add({
    bottleID,
    reporterClientID: uid,
    blockedClientID: bottle.clientID,
    createdAt: FieldValue.serverTimestamp()
  });

  await bottleRef.set({
    blockedAt: FieldValue.serverTimestamp(),
    blockCount: FieldValue.increment(1)
  }, { merge: true });

  response.json({ ok: true });
});

export const returnBottleToSea = onRequest({ region: "asia-northeast1" }, async (request, response) => {
  if (request.method !== "POST") {
    response.status(405).json({ error: "method-not-allowed" });
    return;
  }

  const uid = await authenticatedUID(request);
  if (!uid) {
    response.status(401).json({ error: "unauthenticated" });
    return;
  }

  const body = request.body as ReturnBottleRequest;
  const bottleID = cleanText(body.bottleID, 120);
  if (!bottleID) {
    response.status(400).json({ error: "invalid-return" });
    return;
  }

  const bottleRef = db.collection("bottles").doc(bottleID);
  const bottleSnapshot = await bottleRef.get();
  if (!bottleSnapshot.exists) {
    // The author may have deleted their account after this bottle was received.
    // Let the recipient remove their local copy without recreating deleted UGC.
    response.json({ ok: true, redistributed: false, reason: "bottle-not-found" });
    return;
  }

  const bottle = bottleSnapshot.data() as StoredBottle;
  if (bottle.isReported === true) {
    // Reported content must never be put back into the delivery pool.
    response.json({ ok: true, redistributed: false, reason: "reported" });
    return;
  }

  await bottleRef.set({
    randomKey: Math.random(),
    returnedAt: FieldValue.serverTimestamp(),
    lastReturnedBy: uid,
    returnCount: FieldValue.increment(1)
  }, { merge: true });

  response.json({ ok: true, redistributed: true });
});

export const deleteAccountData = onRequest({ region: "asia-northeast1" }, async (request, response) => {
  if (request.method !== "POST") {
    response.status(405).json({ error: "method-not-allowed" });
    return;
  }

  const uid = await authenticatedUID(request);
  if (!uid) {
    response.status(401).json({ error: "unauthenticated" });
    return;
  }

  const [bottlesSnapshot, ownReportsSnapshot, authoredReportsSnapshot, ownBlocksSnapshot, blockedByOthersSnapshot] =
    await Promise.all([
      db.collection("bottles").where("clientID", "==", uid).get(),
      db.collection("reports").where("reporterClientID", "==", uid).get(),
      db.collection("reports").where("bottleAuthorClientID", "==", uid).get(),
      db.collection("blocks").where("reporterClientID", "==", uid).get(),
      db.collection("blocks").where("blockedClientID", "==", uid).get()
    ]);

  // Older report records do not have bottleAuthorClientID. Resolve those by
  // the IDs of this user's authored bottles so account deletion also removes
  // historical report data.
  const authoredBottleIDs = bottlesSnapshot.docs.map((doc) => doc.id);
  const authoredBottleIDChunks: string[][] = [];
  for (let index = 0; index < authoredBottleIDs.length; index += 30) {
    authoredBottleIDChunks.push(authoredBottleIDs.slice(index, index + 30));
  }
  const historicalReportSnapshots = await Promise.all(
    authoredBottleIDChunks.map((bottleIDChunk) =>
      db.collection("reports").where("bottleID", "in", bottleIDChunk).get()
    )
  );

  const documentPaths = new Set<string>();
  [
    bottlesSnapshot,
    ownReportsSnapshot,
    authoredReportsSnapshot,
    ownBlocksSnapshot,
    blockedByOthersSnapshot,
    ...historicalReportSnapshots
  ].forEach((snapshot) => {
    snapshot.docs.forEach((doc) => documentPaths.add(doc.ref.path));
  });

  // BulkWriter safely handles more than Firestore's 500-operation batch limit.
  const writer = db.bulkWriter();
  documentPaths.forEach((path) => writer.delete(db.doc(path)));
  await writer.close();

  // The private cloud shelf lives in a subcollection, so delete recursively.
  await db.recursiveDelete(db.collection("users").doc(uid));

  response.json({
    ok: true,
    deletedBottles: bottlesSnapshot.size,
    deletedReports: [...documentPaths].filter((path) => path.startsWith("reports/")).length,
    deletedBlocks: [...documentPaths].filter((path) => path.startsWith("blocks/")).length,
    deletedPrivateUserData: true
  });
});

async function authenticatedUID(request: { headers: { authorization?: string } }) {
  const authorization = request.headers.authorization;
  if (!authorization?.startsWith("Bearer ")) {
    return undefined;
  }

  try {
    const idToken = authorization.slice("Bearer ".length);
    const decodedToken = await getAuth().verifyIdToken(idToken);
    return decodedToken.uid;
  } catch {
    return undefined;
  }
}

function normalizeBottle(body: ExchangeBottleRequest, uid: string): StoredBottle | undefined {
  const text = cleanText(body.text, maxBottleTextLength);
  const bottleColor = normalizeBottleColor(body.bottleColor);
  const driftedAt = body.driftedAt ? new Date(body.driftedAt) : new Date();

  if (!text || Number.isNaN(driftedAt.getTime())) {
    return undefined;
  }

  if (containsUnsafeText(text)) {
    return undefined;
  }

  return {
    clientID: uid,
    text,
    bottleColor,
    driftedAt: Timestamp.fromDate(driftedAt),
    randomKey: Math.random(),
    createdAt: FieldValue.serverTimestamp()
  };
}

async function findDeliveredBottle(
  clientID: string,
  ownID: string,
  randomKey: number,
  blockedClientIDs: Set<string>
) {
  const laterSnapshot = await db.collection("bottles")
    .where("randomKey", ">=", randomKey)
    .orderBy("randomKey")
    .get();

  const laterMatch = await pickMatch(laterSnapshot.docs, clientID, ownID, blockedClientIDs);
  if (laterMatch) {
    return laterMatch;
  }

  const earlierSnapshot = await db.collection("bottles")
    .where("randomKey", "<", randomKey)
    .orderBy("randomKey")
    .get();

  return pickMatch(earlierSnapshot.docs, clientID, ownID, blockedClientIDs);
}

async function pickMatch(
  docs: FirebaseFirestore.QueryDocumentSnapshot[],
  clientID: string,
  ownID: string,
  blockedClientIDs: Set<string>
): Promise<DeliveredBottle | undefined> {
  const match = docs.find((doc) => {
    const data = doc.data() as StoredBottle;
    return doc.id !== ownID &&
      data.clientID !== clientID &&
      data.lastReturnedBy !== clientID &&
      data.isReported !== true &&
      !blockedClientIDs.has(data.clientID);
  });

  if (!match) {
    return undefined;
  }

  await match.ref.set({
    deliveredCount: FieldValue.increment(1),
    lastDeliveredAt: FieldValue.serverTimestamp()
  }, { merge: true });

  const data = match.data() as StoredBottle;
  return {
    serverID: match.id,
    text: data.text,
    bottleColor: normalizeBottleColor(data.bottleColor),
    driftedAt: data.driftedAt.toDate().toISOString()
  };
}

async function getBlockedClientIDs(clientID: string) {
  const snapshot = await db.collection("blocks")
    .where("reporterClientID", "==", clientID)
    .limit(200)
    .get();

  return new Set(snapshot.docs
    .map((doc) => doc.data().blockedClientID)
    .filter((blockedClientID): blockedClientID is string => typeof blockedClientID === "string"));
}

function fallbackDeliveredBottle(bottle: StoredBottle): DeliveredBottle {
  const seed = `${bottle.clientID}:${bottle.text}:${bottle.randomKey}`;
  const fallback = fallbackBottles[Math.abs(hashString(seed)) % fallbackBottles.length];

  return {
    ...fallback,
    driftedAt: new Date().toISOString()
  };
}

function normalizeBottleColor(value: unknown): BottleColor {
  if (typeof value === "string" && allowedBottleColors.has(value as BottleColor)) {
    return value as BottleColor;
  }

  return "seaGreen";
}

function cleanText(value: unknown, maxLength: number) {
  if (typeof value !== "string") {
    return undefined;
  }

  const trimmed = value.trim();
  if (trimmed.length === 0 || trimmed.length > maxLength) {
    return undefined;
  }

  return trimmed;
}

function containsUnsafeText(value: string) {
  const normalized = value.normalize("NFKC").replace(/\s+/g, " ");
  return unsafeContentPatterns.some((pattern) => pattern.test(normalized));
}

function hashString(value: string) {
  let hash = 0;
  for (let index = 0; index < value.length; index++) {
    hash = ((hash << 5) - hash) + value.charCodeAt(index);
    hash |= 0;
  }
  return hash;
}
