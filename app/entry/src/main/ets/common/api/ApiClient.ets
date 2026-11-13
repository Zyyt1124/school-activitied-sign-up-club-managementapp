import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ApiConfig } from './ApiConfig';
import { ApiErrorBody } from '../models';

export class ApiError extends Error {
  code: string;
  status: number;

  constructor(code: string, message: string, status: number) {
    super(message);
    this.code = code;
    this.status = status;
  }
}

/**
 * 唯一允许发起网络请求的类。
 *
 * 约定：
 *  - 所有请求带 Authorization: Bearer <token>
 *  - 写操作可带 Idempotency-Key，服务端据此去重
 *  - 非 2xx 统一解析为 ApiError，页面只处理业务错误
 */
export class ApiClient {
  private static token: string = '';

  static setToken(token: string): void {
    ApiClient.token = token;
  }

  static clearToken(): void {
    ApiClient.token = '';
  }

  static async get<T>(path: string): Promise<T> {
    return ApiClient.request<T>(http.RequestMethod.GET, path, undefined, '');
  }

  static async post<T>(path: string, body: Object, idempotencyKey: string = ''): Promise<T> {
    return ApiClient.request<T>(http.RequestMethod.POST, path, body, idempotencyKey);
  }

  static async del<T>(path: string, idempotencyKey: string = ''): Promise<T> {
    return ApiClient.request<T>(http.RequestMethod.DELETE, path, undefined, idempotencyKey);
  }

  private static async request<T>(
    method: http.RequestMethod,
    path: string,
    body: Object | undefined,
    idempotencyKey: string
  ): Promise<T> {
    const client = http.createHttp();
    const headers: Record<string, string> = {
      'Content-Type': 'application/json'
    };
    if (ApiClient.token.length > 0) {
      headers['Authorization'] = `Bearer ${ApiClient.token}`;
    }
    if (idempotencyKey.length > 0) {
      headers['Idempotency-Key'] = idempotencyKey;
    }

    const options: http.HttpRequestOptions = {
      method: method,
      header: headers,
      connectTimeout: ApiConfig.connectTimeoutMs,
      readTimeout: ApiConfig.readTimeoutMs,
      expectDataType: http.HttpDataType.STRING
    };
    if (body !== undefined) {
      options.extraData = JSON.stringify(body);
    }

    try {
      const response = await client.request(`${ApiConfig.baseUrl}${path}`, options);
      const text: string = response.result as string;
      if (response.responseCode >= 200 && response.responseCode < 300) {
        if (text.length === 0) {
          return undefined as T;
        }
        return JSON.parse(text) as T;
      }

      let errorBody: ApiErrorBody = {
        code: `HTTP_${response.responseCode}`,
        message: '服务暂时不可用，请稍后重试'
      };
      try {
        errorBody = JSON.parse(text) as ApiErrorBody;
      } catch (parseError) {
        const ignored = parseError as BusinessError;
        console.warn(`failed to parse error body: ${ignored.message}`);
      }
      throw new ApiError(errorBody.code, errorBody.message, response.responseCode);
    } finally {
      client.destroy();
    }
  }
}
