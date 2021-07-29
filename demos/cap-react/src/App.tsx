import {
  IonApp,
  IonToolbar,
  IonTitle,
  IonContent,
  IonGrid,
  IonRow,
  IonCol,
  IonImg,
  IonSpinner,
  IonButton,
  IonHeader,
} from "@ionic/react";

/* Core CSS required for Ionic components to work properly */
import "@ionic/react/css/core.css";

/* Basic CSS for apps built with Ionic */
import "@ionic/react/css/normalize.css";
import "@ionic/react/css/structure.css";
import "@ionic/react/css/typography.css";

/* Optional CSS utils that can be commented out */
import "@ionic/react/css/padding.css";
import "@ionic/react/css/float-elements.css";
import "@ionic/react/css/text-alignment.css";
import "@ionic/react/css/text-transformation.css";
import "@ionic/react/css/flex-utils.css";
import "@ionic/react/css/display.css";

/* Theme variables */
import "./theme/variables.css";
import { Component } from "react";
import {
  ApproovLoggableToken,
  ApproovHttp,
  HTTPResponse,
} from "@ionic-native/approov-advanced-http";
import React from "react";

interface AppState {
  message: string;
  imageUrl: string;
  isLoading: boolean;
  loggableToken?: ApproovLoggableToken;
}

export class App extends Component<any, AppState> {
  private http = ApproovHttp;
  readonly host = "https://shapes.approov.io";
  readonly imageBaseUrl = "assets/";
  readonly imageExtension = "png";
  readonly VERSION = "v1" as string; // Change To v2 when using Approov
  readonly HELLO_URL = `${this.host}/v1/hello`;
  readonly SHAPE_URL = `${this.host}/${this.VERSION}/shapes`;

  constructor(props: any) {
    super(props);
    this.state = {
      message: "Tap Hello to Start...",
      isLoading: false,
      imageUrl: this.getImageUrl("approov"),
    };

    if (this.isApproov()) {
      this.http.initializeApproov();
    }
  }

  async onHelloClick() {
    this.presentLoadingIndicator();
    try {
      const response = await this.http.get(this.HELLO_URL, {}, {});
      this.hideLoadingIndicator();
      const data = JSON.parse(response.data);
      this.setState({
        message: data.text,
        imageUrl: this.getImageUrl("hello"),
      });
    } catch (err) {
      this.onAPIError(err);
    }
  }

  async onShapeClick() {
    this.presentLoadingIndicator();
    try {
      const response = await this.http.get(this.SHAPE_URL, {}, {});
      this.hideLoadingIndicator();
      const data = JSON.parse(response.data);
      this.setState({
        message: data.status,
        imageUrl: this.getImageUrl(data.shape.toLowerCase()),
        loggableToken: this.isApproov()
          ? await this.http.getApproovLoggableToken(this.host)
          : undefined,
      });
    } catch (err) {
      this.onAPIError(err);
      if (this.isApproov()) {
        this.setState({
          loggableToken: await this.http.getApproovLoggableToken(this.host),
        });
      }
    }
  }

  getImageUrl(name: string): string {
    return `${this.imageBaseUrl}${name}.${this.imageExtension}`;
  }

  private onAPIError(err: HTTPResponse) {
    this.hideLoadingIndicator();
    let message: string;
    try {
      const error = JSON.parse(err.error as string);
      message = `Status Code: ${err.status}, ${error.status}`;
    } catch {
      message = `Status Code: ${err.status}, ${err.error}`;
    }

    this.setState({
      message,
      imageUrl: this.getImageUrl("confused"),
    });
  }

  private presentLoadingIndicator() {
    this.setState({
      isLoading: true,
      imageUrl: this.getImageUrl("approov"),
      message: "Fetching Data.....",
    });
  }

  private hideLoadingIndicator() {
    this.setState({ isLoading: false, loggableToken: undefined });
  }

  private isApproov(): boolean {
    return this.VERSION === "v2";
  }

  render() {
    return (
      <IonApp>
        <IonHeader>
          <IonToolbar>
            <IonTitle className="ion-text-center">Approov React</IonTitle>
          </IonToolbar>
        </IonHeader>

        <IonContent>
          <IonGrid className="full-height">
            <IonRow className="ion-justify-content-center ion-align-items-center container">
              <div className="ion-text-center">
                <IonImg className="image" src={this.state.imageUrl} />
                {this.state.isLoading && <IonSpinner name="crescent" />}
                <p>{this.state.message}</p>
                {this.state.loggableToken && (
                  <p> {JSON.stringify(this.state.loggableToken, null, 2)} </p>
                )}
              </div>
            </IonRow>
            <IonRow>
              <IonCol>
                <div className="button__container">
                  <IonButton
                    className="button__container--hello"
                    onClick={this.onHelloClick.bind(this)}
                  >
                    Hello
                  </IonButton>
                  <IonButton
                    className="button__container--shape"
                    onClick={this.onShapeClick.bind(this)}
                  >
                    Shape
                  </IonButton>
                </div>
              </IonCol>
            </IonRow>
          </IonGrid>
        </IonContent>
      </IonApp>
    );
  }
}

export default App;
