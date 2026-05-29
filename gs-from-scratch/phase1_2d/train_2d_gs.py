"""
2D Gaussian Splatting --- 밑바닥부터 직접 구현 (Phase 1)
========================================================

목표
----
타겟 이미지 한 장을 N개의 '2D 가우시안'으로 재현(fitting)하면서,
3D Gaussian Splatting(3DGS)의 두 가지 핵심을 직접 체득한다.

  1) 미분 가능한 렌더링(differentiable rendering) = "splatting"
  2) 경사하강(gradient descent)으로 가우시안 파라미터를 학습

3D로 가기 전에 2D에서 원리를 100% 이해하는 것이 이 단계의 목적이다.
(3DGS와의 차이점은 ../README.md 참고)

각 2D 가우시안의 학습 파라미터
------------------------------
  - position  (x, y)     : 중심 위치            -> 그대로 학습
  - log_scale (sx, sy)   : 크기(타원 반경)       -> exp 로 양수 보장
  - theta                : 회전각               -> 그대로 학습
  - color     (r, g, b)  : 색                   -> sigmoid 로 [0,1]
  - opacity              : 불투명도 alpha        -> sigmoid 로 [0,1]
  - depth     z          : 앞뒤 순서(블렌딩용)    -> 그대로 학습

렌더링(forward)은 라이브러리 없이 직접 구현한다
-----------------------------------------------
  공분산   Sigma      = R S Sᵀ Rᵀ           (R: 회전, S: 스케일)
  역행렬   Sigma⁻¹    = R diag(1/sx², 1/sy²) Rᵀ
  가우시안 G(p)        = exp(-½ (p-μ)ᵀ Sigma⁻¹ (p-μ))
  알파합성 (front-to-back over compositing) 으로 픽셀 색을 누적.

backward(미분)는 PyTorch autograd 가 자동으로 처리한다.
=> "forward 를 직접 짜서 이해하고, 미분 가능하게 만든다" 가 이 단계의 핵심.

실행 예시
---------
  python train_2d_gs.py                       # 합성 타겟으로 실행 (의존성 없음)
  python train_2d_gs.py --image my_photo.jpg  # 내 사진을 가우시안으로 재현
  python train_2d_gs.py --num-gaussians 1500 --size 128 --steps 600
"""

import argparse
import math
import os

import numpy as np
import torch
import torch.nn as nn
from PIL import Image


# ---------------------------------------------------------------------------
# 타겟 이미지
# ---------------------------------------------------------------------------
def make_synthetic_target(size: int) -> np.ndarray:
    """외부 파일 없이도 돌아가도록 합성 타겟을 만든다 (그라디언트 + 도형)."""
    H = W = size
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    u, v = xx / (W - 1), yy / (H - 1)
    img = np.stack([0.30 + 0.60 * u,        # R
                    0.30 + 0.60 * v,        # G
                    0.65 - 0.45 * u], -1)   # B

    def disk(cx, cy, r, color):
        mask = (xx - cx) ** 2 + (yy - cy) ** 2 < r * r
        for k in range(3):
            img[..., k][mask] = color[k]

    disk(W * 0.30, H * 0.35, size * 0.16, (0.95, 0.25, 0.25))
    disk(W * 0.68, H * 0.30, size * 0.12, (0.20, 0.80, 0.95))
    disk(W * 0.55, H * 0.70, size * 0.18, (0.98, 0.85, 0.20))
    return np.clip(img, 0, 1).astype(np.float32)


def load_target(path: str, size: int) -> np.ndarray:
    img = Image.open(path).convert("RGB").resize((size, size), Image.LANCZOS)
    return np.asarray(img, dtype=np.float32) / 255.0


# ---------------------------------------------------------------------------
# 가우시안 집합 (학습 대상 파라미터)
# ---------------------------------------------------------------------------
class Gaussians2D(nn.Module):
    def __init__(self, n: int, target_hw3: np.ndarray, device: str):
        super().__init__()
        H, W, _ = target_hw3.shape

        # 위치: 정규화 좌표 [-1, 1]
        pos = torch.rand(n, 2, device=device) * 2 - 1
        self.position = nn.Parameter(pos)

        # 크기: log-scale 로 저장해 항상 양수. 이미지의 약 4% 반경에서 시작
        self.log_scale = nn.Parameter(torch.full((n, 2), math.log(0.04), device=device))

        # 회전각
        self.theta = nn.Parameter(torch.rand(n, device=device) * math.pi)

        # 색: 초기값을 '그 위치의 타겟 픽셀 색'으로 주면 수렴이 빨라진다 (logit 으로 저장)
        tgt = torch.from_numpy(target_hw3).to(device)               # (H, W, 3)
        px = ((pos[:, 0] * 0.5 + 0.5) * (W - 1)).long().clamp(0, W - 1)
        py = ((pos[:, 1] * 0.5 + 0.5) * (H - 1)).long().clamp(0, H - 1)
        sampled = tgt[py, px].clamp(1e-3, 1 - 1e-3)                 # (n, 3)
        self.color = nn.Parameter(torch.logit(sampled))

        # 불투명도: alpha ~ 0.2 에서 시작 (sigmoid(-1.4) ≈ 0.198)
        self.opacity = nn.Parameter(torch.full((n,), -1.4, device=device))

        # 깊이(앞뒤 순서)
        self.depth = nn.Parameter(torch.rand(n, device=device))

    def inv_cov(self):
        """Sigma⁻¹ = [[a, b], [b, d]] 를 분석적으로 계산 (각각 shape (N,))."""
        sx = torch.exp(self.log_scale[:, 0])
        sy = torch.exp(self.log_scale[:, 1])
        c, s = torch.cos(self.theta), torch.sin(self.theta)
        ix, iy = 1.0 / (sx * sx), 1.0 / (sy * sy)
        a = c * c * ix + s * s * iy
        b = c * s * (ix - iy)
        d = s * s * ix + c * c * iy
        return a, b, d


# ---------------------------------------------------------------------------
# 렌더러 (직접 구현한 미분가능 splatting)
# ---------------------------------------------------------------------------
def render(g: Gaussians2D, grid: torch.Tensor, H: int, W: int, bg: torch.Tensor) -> torch.Tensor:
    a, b, d = g.inv_cov()                                    # 각 (N,)
    mu = g.position                                          # (N, 2)

    # 1) 각 픽셀에서 각 가우시안 값 G 계산
    dx = grid[:, 0].unsqueeze(0) - mu[:, 0].unsqueeze(1)     # (N, P)
    dy = grid[:, 1].unsqueeze(0) - mu[:, 1].unsqueeze(1)     # (N, P)
    power = (a.unsqueeze(1) * dx * dx
             + 2 * b.unsqueeze(1) * dx * dy
             + d.unsqueeze(1) * dy * dy)                     # (N, P) = 마할라노비스 거리²
    G = torch.exp(-0.5 * power)                              # (N, P)

    # 2) 유효 알파 = 불투명도 × 가우시안 값
    alpha = (torch.sigmoid(g.opacity).unsqueeze(1) * G).clamp(max=0.999)   # (N, P)
    color = torch.sigmoid(g.color)                          # (N, 3)

    # 3) 깊이 순으로 정렬 (front-to-back)
    order = torch.argsort(g.depth)
    alpha, color = alpha[order], color[order]

    # 4) 알파 합성 (over compositing)
    #    T_i = Π_{j<i} (1 - alpha_j)  <- 누적 투과율(transmittance)
    one_minus = 1.0 - alpha                                 # (N, P)
    cp = torch.cumprod(one_minus, dim=0)                    # (N, P)
    T = torch.cat([torch.ones_like(cp[:1]), cp[:-1]], dim=0)   # exclusive cumprod
    weight = alpha * T                                      # (N, P)

    out = torch.einsum("np,nc->pc", weight, color)         # (P, 3)
    out = out + cp[-1].unsqueeze(1) * bg                    # 남은 투과율만큼 배경색
    return out.reshape(H, W, 3)


# ---------------------------------------------------------------------------
# 유틸
# ---------------------------------------------------------------------------
def save_png(arr_hw3: torch.Tensor, path: str):
    a = (arr_hw3.clamp(0, 1).detach().cpu().numpy() * 255).astype(np.uint8)
    Image.fromarray(a).save(path)


# ---------------------------------------------------------------------------
# 학습 루프
# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description="2D Gaussian Splatting from scratch")
    ap.add_argument("--num-gaussians", type=int, default=700)
    ap.add_argument("--steps", type=int, default=400)
    ap.add_argument("--size", type=int, default=96)
    ap.add_argument("--image", type=str, default=None, help="타겟 이미지 경로(없으면 합성)")
    ap.add_argument("--outdir", type=str,
                    default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "outputs"))
    ap.add_argument("--save-every", type=int, default=40)
    args = ap.parse_args()

    os.makedirs(args.outdir, exist_ok=True)
    device = "cpu"
    torch.manual_seed(0)

    target_np = load_target(args.image, args.size) if args.image else make_synthetic_target(args.size)
    H, W, _ = target_np.shape
    target = torch.from_numpy(target_np).to(device)             # (H, W, 3)
    save_png(target, os.path.join(args.outdir, "target.png"))

    # 픽셀 그리드 (정규화 [-1, 1])
    ys = torch.linspace(-1, 1, H, device=device)
    xs = torch.linspace(-1, 1, W, device=device)
    gy, gx = torch.meshgrid(ys, xs, indexing="ij")
    grid = torch.stack([gx.reshape(-1), gy.reshape(-1)], dim=1)  # (P, 2)
    bg = torch.ones(3, device=device)                           # 흰 배경

    g = Gaussians2D(args.num_gaussians, target_np, device)

    # 파라미터 그룹별 학습률 (실제 3DGS 도 그룹마다 다른 lr 을 쓴다)
    opt = torch.optim.Adam([
        {"params": [g.position],  "lr": 5e-3},
        {"params": [g.log_scale], "lr": 1e-2},
        {"params": [g.theta],     "lr": 1e-2},
        {"params": [g.color],     "lr": 2e-2},
        {"params": [g.opacity],   "lr": 3e-2},
        {"params": [g.depth],     "lr": 5e-3},
    ])

    frames = []
    print(f"학습 시작: {args.num_gaussians} gaussians, {args.size}x{args.size}, {args.steps} steps (CPU)")
    for step in range(1, args.steps + 1):
        out = render(g, grid, H, W, bg)
        l1 = (out - target).abs().mean()
        mse = ((out - target) ** 2).mean()
        loss = l1 + 0.5 * mse                                   # 3DGS 는 L1 + D-SSIM 사용
        opt.zero_grad()
        loss.backward()
        opt.step()

        if step == 1 or step % args.save_every == 0:
            psnr = -10 * math.log10(mse.item() + 1e-12)
            print(f"step {step:4d} | loss {loss.item():.4f} | L1 {l1.item():.4f} | PSNR {psnr:5.2f} dB")
            save_png(out, os.path.join(args.outdir, f"step_{step:04d}.png"))
            frames.append((out.clamp(0, 1).detach().cpu().numpy() * 255).astype(np.uint8))

    # 최종 비교 (타겟 | 렌더)
    final = render(g, grid, H, W, bg)
    comp = torch.cat([target, final], dim=1)
    save_png(comp, os.path.join(args.outdir, "compare_target_vs_render.png"))

    # 진행 과정 GIF
    try:
        imgs = [Image.fromarray(f) for f in frames]
        if imgs:
            imgs[0].save(os.path.join(args.outdir, "progress.gif"),
                         save_all=True, append_images=imgs[1:], duration=120, loop=0)
    except Exception as e:
        print("gif skip:", e)

    print("완료. 결과 폴더:", args.outdir)


if __name__ == "__main__":
    main()
