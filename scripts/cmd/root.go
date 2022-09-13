package cmd

import (
	"fmt"
	"log"
	"os"

	"github.com/spf13/cobra"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

type RootArgs struct {
	VegaNetworkName string
	Debug           bool
	Logger          *zap.Logger
}

var rootArgs RootArgs

var rootCmd = &cobra.Command{
	Use:   "network-config",
	Short: "Manage networks config",
	Long:  `Manage networks config`,
	PersistentPreRun: func(cmd *cobra.Command, args []string) {
		var err error
		cfg := zap.NewProductionConfig()
		if rootArgs.Debug {
			cfg.Level.SetLevel(zap.DebugLevel)
		}
		cfg.Encoding = "console"
		cfg.EncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder
		rootArgs.Logger, err = cfg.Build()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Failed to find latest checkpoint: %v\n", err)
			os.Exit(1)
		}
	},
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Whoops. There was an error while executing your CLI '%s'", err)
		os.Exit(1)
	}
}

func init() {
	rootCmd.PersistentFlags().StringVar(&rootArgs.VegaNetworkName, "network", "", "Vega Network")
	if err := rootCmd.MarkPersistentFlagRequired("network"); err != nil {
		log.Fatalf("%v\n", err)
	}
	rootCmd.PersistentFlags().BoolVar(&rootArgs.Debug, "debug", false, "Print debug logs")
}
