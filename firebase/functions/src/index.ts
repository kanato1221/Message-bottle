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

type StoredBottle = {
  clientID: string;
  text: string;
  bottleColor: BottleColor;
  driftedAt: Timestamp;
  randomKey: number;
  createdAt: FieldValue;
  isReported?: boolean;
  deliveredCount?: number;
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

  const bottle = normalizeBottle(request.body as ExchangeBottleRequest, uid);
  if (!bottle) {
    response.status(400).json({ error: "invalid-bottle" });
    return;
  }

  const docRef = await db.collection("bottles").add(bottle);
  const deliveredBottle = await findDeliveredBottle(bottle.clientID, docRef.id, bottle.randomKey);

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
    createdAt: FieldValue.serverTimestamp()
  });

  response.json({ ok: true });
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

  const bottlesSnapshot = await db.collection("bottles")
    .where("clientID", "==", uid)
    .limit(450)
    .get();

  const reportsSnapshot = await db.collection("reports")
    .where("reporterClientID", "==", uid)
    .limit(50)
    .get();

  const batch = db.batch();
  bottlesSnapshot.docs.forEach((doc) => batch.delete(doc.ref));
  reportsSnapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();

  response.json({
    ok: true,
    deletedBottles: bottlesSnapshot.size,
    deletedReports: reportsSnapshot.size
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

async function findDeliveredBottle(clientID: string, ownID: string, randomKey: number) {
  const laterSnapshot = await db.collection("bottles")
    .where("randomKey", ">=", randomKey)
    .orderBy("randomKey")
    .limit(20)
    .get();

  const laterMatch = await pickMatch(laterSnapshot.docs, clientID, ownID);
  if (laterMatch) {
    return laterMatch;
  }

  const earlierSnapshot = await db.collection("bottles")
    .where("randomKey", "<", randomKey)
    .orderBy("randomKey")
    .limit(20)
    .get();

  return pickMatch(earlierSnapshot.docs, clientID, ownID);
}

async function pickMatch(
  docs: FirebaseFirestore.QueryDocumentSnapshot[],
  clientID: string,
  ownID: string
): Promise<DeliveredBottle | undefined> {
  const match = docs.find((doc) => {
    const data = doc.data() as StoredBottle;
    return doc.id !== ownID && data.clientID !== clientID && data.isReported !== true;
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
  return /(https?:\/\/|[\w.-]+@[\w.-]+|\d{2,4}-\d{2,4}-\d{3,4})/.test(value);
}

function hashString(value: string) {
  let hash = 0;
  for (let index = 0; index < value.length; index++) {
    hash = ((hash << 5) - hash) + value.charCodeAt(index);
    hash |= 0;
  }
  return hash;
}
