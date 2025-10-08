import { WeatherAnnouncementEngine } from '../engines/WeatherAnnouncementEngine';
import { WeatherData } from '../models/WeatherData';

export interface WeatherSpeechTexts {
  fullAnnouncement: string;
  quickSummary: string;
  currentConditions: string;
  forecastAnnouncement: string;
}

export class WeatherTextSpeechService {
  private static instance: WeatherTextSpeechService;
  private announcementEngine: WeatherAnnouncementEngine;

  private constructor() {
    this.announcementEngine = new WeatherAnnouncementEngine();
  }

  static getInstance(): WeatherTextSpeechService {
    if(!WeatherTextSpeechService.instance) {
      WeatherTextSpeechService.instance = new WeatherTextSpeechService();
    }
    return WeatherTextSpeechService.instance;
  }

  generateAllSpeechTexts(weatherData: WeatherData): WeatherSpeechTexts {
    return {
      fullAnnouncement: this.announcementEngine.generateAnnouncement(weatherData),
      quickSummary: this.announcementEngine.generateQuickSummary(weatherData),
      currentConditions: this.announcementEngine.generateCurrentConditions(weatherData.current),
      forecastAnnouncement: this.announcementEngine.generateForecastAnnouncement(weatherData),
    };
  }

  generateCompleteAnnouncement(weatherData: WeatherData): string {
    return this.announcementEngine.generateAnnouncement(weatherData);
  }

  generateWeatherAnnouncement(weatherData: WeatherData): string {
    return this.announcementEngine.generateAnnouncement(weatherData);
  }

  generateQuickUpdate(weatherData: WeatherData): string {
    return this.announcementEngine.generateQuickSummary(weatherData);
  }

  generateMorningBriefing(weatherData: WeatherData): string {
    const greeting = 'Good Morning! Here is your weather briefing.';
    const weather = this.announcementEngine.generateAnnouncement(weatherData);
    const forecast = this.announcementEngine.generateForecastAnnouncement(weatherData);

    return `${greeting} ${weather} ${forecast} Have a great day!`;
  }

  generateAfternoonUpdate(weatherData: WeatherData): string {
    const greeting = 'Afternoon weather check.';
    const current = this.announcementEngine.generateCurrentConditions(weatherData.current);

    return `${greeting} ${current}`;
  }

  generateEveningSummary(weatherData: WeatherData): string {
    const greeting = 'Evening weather summary.';
    const quick = this.announcementEngine.generateQuickSummary(weatherData);
    const tomorrow = this.announcementEngine.generateForecastAnnouncement(weatherData);

    return `${greeting} Today: ${quick} ${tomorrow}`;
  }
}