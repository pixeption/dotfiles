var bvs = UnityEngine.Object.FindObjectsByType<Game.BoardView>(UnityEngine.FindObjectsSortMode.None);
if (bvs.Length == 0) return "no BoardView";
var bv = bvs[0];
var rootRT = (UnityEngine.RectTransform)bv.Canvas.rootCanvas.transform;
float sf = bv.Canvas.rootCanvas.scaleFactor;
float rw = rootRT.rect.width * sf;
float rh = rootRT.rect.height * sf;

System.Func<UnityEngine.RectTransform, float[]> imgRect = (rt) => {
    var c = new UnityEngine.Vector3[4];
    rt.GetWorldCorners(c);
    float minX = 1e9f, maxX = -1e9f, minY = 1e9f, maxY = -1e9f;
    for (int i = 0; i < 4; i++) {
        var l = rootRT.InverseTransformPoint(c[i]);
        float nx = (l.x - rootRT.rect.xMin) / rootRT.rect.width;
        float ny = (l.y - rootRT.rect.yMin) / rootRT.rect.height;
        float px = nx * rw;
        float py = (1f - ny) * rh; // image y-down
        minX = UnityEngine.Mathf.Min(minX, px); maxX = UnityEngine.Mathf.Max(maxX, px);
        minY = UnityEngine.Mathf.Min(minY, py); maxY = UnityEngine.Mathf.Max(maxY, py);
    }
    return new float[] { minX, minY, maxX - minX, maxY - minY };
};

var ps = UnityEngine.Object.FindObjectsByType<Game.PlayScreen>(UnityEngine.FindObjectsSortMode.None);
var flags = System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance;
var backView = (Game.BoardBackButtonView)typeof(Game.PlayScreen).GetField("_backButton", flags).GetValue(ps[0]);
var hudView = (Game.BoardHudView)typeof(Game.PlayScreen).GetField("_hud", flags).GetValue(ps[0]);

var back = imgRect(backView.ControlRT);
var hud = imgRect(hudView.BandRT);
var board = imgRect(bv.ContentRT);

float cropTop = back[1];
float cropBottom = hud[1] + hud[3];
return string.Format("render={0:F0}x{1:F0} cropTop={2:F1} cropBottom={3:F1} boardX={4:F1} boardY={5:F1} boardW={6:F1} boardH={7:F1}",
    rw, rh, cropTop, cropBottom, board[0], board[1], board[2], board[3]);
