/**
 * 视觉 token 与开题 PPT 的配色保持一致，避免前后端文档、演示材料三套颜色。
 */
export class AppColors {
  static readonly ink: string = '#1F242B';
  static readonly inkSecondary: string = '#3C424A';
  static readonly muted: string = '#8B939D';
  static readonly blue: string = '#2E6FB8';
  static readonly orange: string = '#C16B2E';
  static readonly bg: string = '#F5F7F9';
  static readonly line: string = '#DEE2E7';
  static readonly white: string = '#FFFFFF';
  static readonly danger: string = '#C0392B';
  static readonly success: string = '#2E8B57';
}

export class AppSpace {
  static readonly page: number = 16;
  static readonly card: number = 16;
  static readonly section: number = 24;
  static readonly radius: number = 14;
}

export class AppText {
  static readonly title: number = 26;
  static readonly pageTitle: number = 22;
  static readonly section: number = 17;
  static readonly body: number = 14;
  static readonly caption: number = 12;
}
