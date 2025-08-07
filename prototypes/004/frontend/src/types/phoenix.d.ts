declare module 'phoenix' {
  export class Socket {
    constructor(url: string, options?: any);
    connect(): void;
    disconnect(): void;
    channel(topic: string, params?: any): Channel;
    onOpen(callback: () => void): void;
    onError(callback: (error: any) => void): void;
    onClose(callback: () => void): void;
  }

  export class Channel {
    join(): Push;
    leave(): Push;
    push(event: string, payload?: any): Push;
    on(event: string, callback: (payload: any) => void): void;
  }

  export class Push {
    receive(status: string, callback: (response: any) => void): Push;
  }
}