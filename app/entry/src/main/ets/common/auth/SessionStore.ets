import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { UserProfile } from '../models';

const STORE_NAME: string = 'campus_session';
const KEY_TOKEN: string = 'token';
const KEY_USER: string = 'user';

export interface Session {
  token: string;
  user: UserProfile;
}

/**
 * 本地会话存储。
 *
 * 说明：preferences 不是加密存储。课程演示阶段可以接受；
 * 上架前应把 token 放进 HUKS（UniversalKeystoreKit），
 * 或至少缩短 token 有效期并支持服务端主动失效。
 */
export class SessionStore {
  private static prefs: preferences.Preferences | null = null;
  private static initPromise: Promise<void> | null = null;

  static init(context: common.UIAbilityContext): Promise<void> {
    if (SessionStore.initPromise === null) {
      SessionStore.initPromise = SessionStore.doInit(context);
    }
    return SessionStore.initPromise;
  }

  private static async doInit(context: common.UIAbilityContext): Promise<void> {
    SessionStore.prefs = await preferences.getPreferences(context, { name: STORE_NAME });
  }

  static async save(token: string, user: UserProfile): Promise<void> {
    const store = SessionStore.prefs;
    if (store === null) {
      return;
    }
    await store.put(KEY_TOKEN, token);
    await store.put(KEY_USER, JSON.stringify(user));
    await store.flush();
  }

  static async load(): Promise<Session | null> {
    const store = SessionStore.prefs;
    if (store === null) {
      return null;
    }
    try {
      const token = await store.get(KEY_TOKEN, '') as string;
      const userJson = await store.get(KEY_USER, '') as string;
      if (token.length === 0 || userJson.length === 0) {
        return null;
      }
      return {
        token: token,
        user: JSON.parse(userJson) as UserProfile
      };
    } catch (error) {
      const e = error as BusinessError;
      console.warn(`failed to load session: ${e.message}`);
      return null;
    }
  }

  static async clear(): Promise<void> {
    const store = SessionStore.prefs;
    if (store === null) {
      return;
    }
    await store.delete(KEY_TOKEN);
    await store.delete(KEY_USER);
    await store.flush();
  }
}
