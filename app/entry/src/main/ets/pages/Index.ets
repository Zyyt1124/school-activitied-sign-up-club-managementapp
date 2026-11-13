import { router } from '@kit.ArkUI';
import { AppColors, AppText } from '../common/constants/AppTheme';
import { SessionStore } from '../common/auth/SessionStore';
import { ApiClient } from '../common/api/ApiClient';

@Entry
@Component
struct Index {
  @State hint: string = '正在恢复登录状态…';

  aboutToAppear(): void {
    this.bootstrap();
  }

  private async bootstrap(): Promise<void> {
    const session = await SessionStore.load();
    if (session !== null) {
      ApiClient.setToken(session.token);
      this.hint = '欢迎回来，正在进入…';
      router.replaceUrl({ url: 'pages/Main' });
      return;
    }
    router.replaceUrl({ url: 'pages/Login' });
  }

  build() {
    Column({ space: 18 }) {
      Text('校园活动与社团管理')
        .fontSize(AppText.pageTitle)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.ink)
      Text('仓颉 + ArkTS · 鸿蒙原生')
        .fontSize(AppText.caption)
        .fontColor(AppColors.muted)
      LoadingProgress()
        .width(36)
        .height(36)
        .color(AppColors.blue)
      Text(this.hint)
        .fontSize(AppText.caption)
        .fontColor(AppColors.muted)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.bg)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
