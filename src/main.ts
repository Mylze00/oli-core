import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  // On crée l'application
  const app = await NestFactory.create(AppModule);

  // Active le CORS pour autoriser les requêtes venant de Flutter (Web/Mobile)
  app.enableCors();

  // Définit le préfixe global
  app.setGlobalPrefix('api');

  // IMPORTANT : On écoute sur '0.0.0.0' pour accepter les connexions de l'émulateur/réseau
  await app.listen(3000, '0.0.0.0');
  
  console.log('🚀 OLI backend running on http://localhost:3000/api');
}
bootstrap();