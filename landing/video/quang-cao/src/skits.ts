// Danh sách kịch bản skits/*.json (do make_skit_voice.py thêm segments/total). Thêm module mới → thêm vào đây.
import chamCong from '../skits/cham-cong.json';
import xepCa from '../skits/xep-ca.json';
import nghiPhep from '../skits/nghi-phep.json';
import duyetCong from '../skits/duyet-cong.json';
import tinhLuong from '../skits/tinh-luong.json';
import nhatKy from '../skits/nhat-ky.json';
import baoCao from '../skits/bao-cao.json';
import doiCa from '../skits/doi-ca.json';
import xoayCa from '../skits/xoay-ca.json';
import phanQuyen from '../skits/phan-quyen.json';
import baoMat from '../skits/bao-mat.json';

export type SkitSpec = {
  slug: string; total: number; paper: string[]; result: string[]; labels?: { nv?: string; sep?: string };
  segments: { who: string; text: string; start: number; voice: number; len: number }[];
  sol: { kind: 'phone' | 'screen'; img: string; title: string[]; cap: string[] }[];
};
export const SKITS: Record<string, SkitSpec> = {
  'cham-cong': chamCong, 'xep-ca': xepCa, 'nghi-phep': nghiPhep, 'duyet-cong': duyetCong,
  'tinh-luong': tinhLuong, 'nhat-ky': nhatKy, 'bao-cao': baoCao,
  'doi-ca': doiCa, 'xoay-ca': xoayCa, 'phan-quyen': phanQuyen, 'bao-mat': baoMat,
} as Record<string, SkitSpec>;
