/**
 * 端云契约的 TypeScript 镜像。
 *
 * 这些类型必须与 docs/03-api-contract.md 以及仓颉侧 campus.api 的 DTO
 * 保持一致。端侧不直接访问数据库，所有数据都通过 HTTPS/JSON 获取。
 */

export enum Role {
  STUDENT = 'student',
  CLUB_LEADER = 'club_leader',
  ADMIN = 'admin'
}

export enum ActivityState {
  DRAFT = 'draft',
  OPEN = 'open',
  CLOSED = 'closed',
  ARCHIVED = 'archived',
  DISABLED = 'disabled'
}

export interface UserProfile {
  userId: number;
  studentId: string;
  name: string;
  role: Role;
  college: string;
}

export interface LoginRequest {
  studentId: string;
  password: string;
}

export interface LoginResponse {
  token: string;
  user: UserProfile;
}

export interface ActivitySummary {
  activityId: number;
  clubId: number;
  clubName: string;
  title: string;
  location: string;
  state: ActivityState;
  remainCount: number;
  maxCount: number;
  signStart: number;
  signEnd: number;
  activityTime: number;
}

export interface ActivityDetail extends ActivitySummary {
  description: string;
  signed: boolean;
}

export interface SignUpReceipt {
  signId: number;
  activityId: number;
  userId: number;
  signTime: number;
  remainCount: number;
}

export interface ApiErrorBody {
  code: string;
  message: string;
  requestId?: string;
}

export interface PageResult<T> {
  items: T[];
  nextCursor: string;
}

export interface ActivityDetailParams {
  activityId: number;
}

/**
 * 无请求体的写操作使用显式空对象，避免 ArkTS 的无类型对象字面量限制。
 */
export class EmptyBody {
}
