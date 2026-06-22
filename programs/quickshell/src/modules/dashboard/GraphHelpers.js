.pragma library

// Build a rounded-rect path on ctx. Does not fill or stroke.
function roundedRect(ctx, x, y, w, h, r) {
    ctx.beginPath()
    ctx.moveTo(x + r, y)
    ctx.lineTo(x + w - r, y)
    ctx.arc(x + w - r, y + r,     r, -Math.PI / 2, 0)
    ctx.lineTo(x + w,  y + h - r)
    ctx.arc(x + w - r, y + h - r, r,  0,            Math.PI / 2)
    ctx.lineTo(x + r,  y + h)
    ctx.arc(x + r,     y + h - r, r,  Math.PI / 2,  Math.PI)
    ctx.lineTo(x,      y + r)
    ctx.arc(x + r,     y + r,     r,  Math.PI,       Math.PI * 1.5)
    ctx.closePath()
}

// Draw a progress bar with properly rounded corners using only path geometry.
//
// Why not ctx.clip(): Qt clips to the bounding rect of the path, not the arc path itself.
// Why not destination-in compositing: unreliable on Qt's Canvas backend.
//
// Solution: draw background as a full rounded rect, then draw each fill segment as a
// "left-rounded, right-straight" path that geometrically fits inside the bar corners.
// No clipping or compositing needed.
//
// segments: [{color: str, frac: 0..1}, ...] drawn left-to-right, later entries on top.
function drawRoundedBar(ctx, width, height, r, bgColor, segments, borderColor) {
    // Background (full rounded rect — transparent corners, visible bar interior)
    roundedRect(ctx, 0, 0, width, height, r)
    ctx.fillStyle = bgColor
    ctx.fill()

    for (const s of segments) {
        if (s.frac <= 0) continue
        const fw = Math.min(s.frac * width, width)
        if (fw >= width - r) {
            // Fill reaches the right corner region — use a full rounded rect.
            roundedRect(ctx, 0, 0, fw, height, r)
        } else if (fw >= 2 * r) {
            // Common case: rounded left corners, straight right edge.
            ctx.beginPath()
            ctx.moveTo(r, 0)
            ctx.lineTo(fw, 0)
            ctx.lineTo(fw, height)
            ctx.lineTo(r, height)
            ctx.arc(r, height - r, r, Math.PI / 2, Math.PI)
            ctx.lineTo(0, r)
            ctx.arc(r, r, r, Math.PI, Math.PI * 1.5)
            ctx.closePath()
        } else {
            // Very thin fill — radius would overlap; plain rect.
            ctx.beginPath()
            ctx.rect(0, 0, fw, height)
        }
        ctx.fillStyle = s.color
        ctx.fill()
    }

    if (borderColor) {
        ctx.strokeStyle = borderColor
        ctx.lineWidth = 1
        roundedRect(ctx, 0.5, 0.5, width - 1, height - 1, r)
        ctx.stroke()
    }
}

// Draw a sparkline (area fill + line). Pass null for either color to skip it.
// hist: array of values; maxVal: the value that maps to full height.
function drawSparkline(ctx, hist, width, height, maxVal, lineColor, fillColor) {
    if (!hist || hist.length < 2) return
    const n = hist.length
    if (fillColor) {
        ctx.beginPath()
        for (let i = 0; i < n; i++) {
            const x = i / 59 * width
            const y = height - (Math.min(hist[i], maxVal) / maxVal) * height
            i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
        }
        ctx.lineTo((n - 1) / 59 * width, height)
        ctx.lineTo(0, height)
        ctx.closePath()
        ctx.fillStyle = fillColor
        ctx.fill()
    }
    if (lineColor) {
        ctx.beginPath()
        for (let i = 0; i < n; i++) {
            const x = i / 59 * width
            const y = height - (Math.min(hist[i], maxVal) / maxVal) * height
            i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
        }
        ctx.strokeStyle = lineColor
        ctx.lineWidth = 1.5
        ctx.stroke()
    }
}

// Draw a thin 0.5 px rectangular canvas border.
function drawBorder(ctx, width, height, color) {
    ctx.strokeStyle = color
    ctx.lineWidth = 0.5
    ctx.strokeRect(0.5, 0.5, width - 1, height - 1)
}

// Format a bytes/s rate to a human-readable string.
function formatRate(bps) {
    if (bps >= 1e9) return (bps / 1e9).toFixed(2) + " GB/s"
    if (bps >= 1e6) return (bps / 1e6).toFixed(1) + " MB/s"
    if (bps >= 1e3) return (bps / 1e3).toFixed(0) + " KB/s"
    return bps.toFixed(0) + " B/s"
}

// Snap a max value up to the nearest stable threshold so the Y axis doesn't jitter.
function snapNetMax(val) {
    const thresholds = [100*1024, 1024*1024, 10*1024*1024, 100*1024*1024, 1024*1024*1024]
    for (const t of thresholds)
        if (val <= t) return t
    return val * 2
}

function snapPowerMax(watts) {
    const thresholds = [5, 10, 15, 20, 30, 50, 75, 100]
    for (const t of thresholds)
        if (watts <= t) return t
    return Math.ceil(watts / 25) * 25
}
